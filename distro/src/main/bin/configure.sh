#!/bin/bash

MAPR_HOME=${MAPR_HOME:-/opt/mapr}
OOZIE_VERSION="4.3.0"
OOZIE_HOME="$MAPR_HOME"/oozie/oozie-"$OOZIE_VERSION"
OOZIE_BIN="$OOZIE_HOME"/bin
MAPR_CONF_DIR="${MAPR_HOME}/conf/conf.d"
DAEMON_CONF="$MAPR_HOME/conf/daemon.conf"
WARDEN_OOZIE_CONF="$OOZIE_HOME"/conf/warden.oozie.conf
OOZIE_TMP_DIR=/tmp/oozieTmp
HADOOP_VER=$(cat "$MAPR_HOME/hadoop/hadoopversion")
OOZIE_SSL=$(cat "$OOZIE_HOME/conf/ooziessl")
secureCluster=0
MAPR_USER=""
MAPR_GROUP=""

# isSecure is set in server/configure.sh
if [ -n "$isSecure" ]; then
    if [ "$isSecure" == "true" ]; then
        secureCluster=1
    fi
fi

changeOoziePermission() {
  if [ -f "$DAEMON_CONF" ]; then
    MAPR_USER=$( awk -F = '$1 == "mapr.daemon.user" { print $2 }' "$DAEMON_CONF")
    MAPR_GROUP=$( awk -F = '$1 == "mapr.daemon.group" { print $2 }' "$DAEMON_CONF")
  else
    MAPR_USER=`logname`
    MAPR_GROUP="$MAPR_USER"
  fi

#
# change permissions
#
  chmod 755 -R $OOZIE_HOME"/oozie-server"
  chmod 777 -R "$OOZIE_TMP_DIR"
  if [ ! -z "$MAPR_USER" ]; then
    chown -R "$MAPR_USER" "$MAPR_HOME/oozie"
    chown -R "$MAPR_USER" "$OOZIE_TMP_DIR"
  fi
  if [ ! -z "$MAPR_GROUP" ]; then
    chgrp -R "$MAPR_GROUP" "$MAPR_HOME/oozie"
    chgrp -R "$MAPR_GROUP" "$OOZIE_TMP_DIR"
  fi
}

configDefaultSsl() {
    #enable SSL if ssl was disabled and cluster is secure
    if [ "$OOZIE_SSL" == false -a ${secureCluster} == 1 ]; then
        sed -i '/OOZIE_HTTPS_KEYSTORE_FILE/s/^#*//g' $OOZIE_HOME/conf/oozie-env.sh
        sed -i '/OOZIE_HTTPS_KEYSTORE_PASS/s/^#*//g' $OOZIE_HOME/conf/oozie-env.sh
        sed -i '/OOZIE_HTTPS_PORT/s/^#*//g' $OOZIE_HOME/conf/oozie-env.sh
        sed -i '/OOZIE_CLIENT_OPTS/s/^#*//g' $OOZIE_HOME/conf/oozie-client-env.sh
    fi
}

#
# Build Oozie war
#
buildOozieWar() {
  # Construct the oozie-setup command.
  if [ ${secureCluster} == 1 -o "$OOZIE_SSL" == true ]; then
    cmd="$OOZIE_HOME/bin/oozie-setup.sh -hadoop "${HADOOP_VER}" "${MAPR_HOME}/hadoop/hadoop-${HADOOP_VER}" -secure"
  else
    cmd="$OOZIE_HOME/bin/oozie-setup.sh -hadoop "${HADOOP_VER}" "${MAPR_HOME}/hadoop/hadoop-${HADOOP_VER}
  fi
  $cmd > /dev/null
}

#
# Copying the warden service config file
#
setupWardenConfFile() {
  if ! [ -d ${MAPR_CONF_DIR} ]; then
    mkdir -p ${MAPR_CONF_DIR} > /dev/null 2>&1
  fi

  # Install warden file
  cp ${WARDEN_OOZIE_CONF} ${MAPR_CONF_DIR}
  chown $MAPR_USER:$MAPR_GROUP ${MAPR_CONF_DIR}/warden.oozie.conf
}

#
# main
#
# typically called from core configure.sh
#

USAGE="usage: $0 [--secure|--customSecure|--unsecure|-EC|-R|--help"
if [ ${#} -gt 1 ]; then
  for i in "$@" ; do
    case "$i" in
      --secure)
        secureCluster=1
        shift
        ;;
      --customSecure|-cs)
        secureCluster=1
        shift
        ;;
      --unsecure)
        secureCluster=0
        shift
        ;;
      --help)
        echo "$USAGE"
        return 0 2>/dev/null || exit 0
        ;;
      -EC|--EC)
         shift
         ;;
       -R|--R)
         shift
         ;;
       --)
        echo "$USAGE"
        return 1 2>/dev/null || exit 1
        ;;
    esac
  done
else
    echo "$USAGE"
    return 1 2>/dev/null || exit 1
fi

#
#create tmp directory if need
#
if [ ! -d ${OOZIE_TMP_DIR} ]; then
  mkdir -p ${OOZIE_TMP_DIR}
fi

# remove state file
if [ -f "$OOZIE_HOME/conf/.not_configured_yet" ]; then
    rm -f "$OOZIE_HOME/conf/.not_configured_yet"
fi

configDefaultSsl
#build oozie war file
buildOozieWar
changeOoziePermission
setupWardenConfFile

true