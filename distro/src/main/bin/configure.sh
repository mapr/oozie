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

#
# Build Oozie war
#
buildOozieWar() {
  # Construct the oozie-setup command.
  if [ "$OOZIE_SSL" == true ]; then
    cmd="$OOZIE_HOME/bin/oozie-setup.sh -hadoop "${HADOOP_VER}" "${MAPR_HOME}/hadoop/hadoop-${HADOOP_VER}" -secure"
  else
    cmd="$OOZIE_HOME/bin/oozie-setup.sh -hadoop "${HADOOP_VER}" "${MAPR_HOME}/hadoop/hadoop-${HADOOP_VER}""
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
}

#
# main
#
# typically called from core configure.sh
#

usage="usage: $0 [--secure|--unsecure|--help"

while [ $# -gt 0 ]; do
  case "$1" in
    --secure)
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
    *)
      echo "$USAGE"
      return 1 2>/dev/null || exit 1
    ;;
  esac
done

#
#create tmp directory if need
#
if [ ! -d ${OOZIE_TMP_DIR} ]; then
  mkdir -p ${OOZIE_TMP_DIR}
fi


#build oozie war file
buildOozieWar
changeOoziePermission
setupWardenConfFile

true