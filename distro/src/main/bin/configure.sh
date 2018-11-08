#!/bin/bash

MAPR_HOME=${MAPR_HOME:-/opt/mapr}
OOZIE_VERSION="5.1.0"
OOZIE_HOME="$MAPR_HOME"/oozie/oozie-"$OOZIE_VERSION"
OOZIE_BIN="$OOZIE_HOME"/bin
MAPR_CONF_DIR="${MAPR_HOME}/conf/"
MAPR_WARDEN_CONF_DIR="${MAPR_HOME}/conf/conf.d"
DAEMON_CONF="$MAPR_HOME/conf/daemon.conf"
WARDEN_OOZIE_CONF="$OOZIE_HOME"/conf/warden.oozie.conf
WARDEN_OOZIE_DEST="$MAPR_WARDEN_CONF_DIR/warden.oozie.conf"
OOZIE_TMP_DIR=/tmp/oozieTmp
HADOOP_VER=$(cat "$MAPR_HOME/hadoop/hadoopversion")
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

configureClientImpersonation() {
    if ! grep -q oozie.service.ProxyUserService.proxyuser.$MAPR_USER.hosts $OOZIE_HOME/conf/oozie-site.xml; then
        sed -i -e "s|</configuration>|  <property>\n    <name>oozie.service.ProxyUserService.proxyuser.$MAPR_USER.hosts</name>\n    <value>*</value>\n  </property>\n</configuration>|" $OOZIE_HOME/conf/oozie-site.xml
    fi
    if ! grep -q oozie.service.ProxyUserService.proxyuser.$MAPR_USER.groups $OOZIE_HOME/conf/oozie-site.xml; then
        sed -i -e "s|</configuration>|  <property>\n    <name>oozie.service.ProxyUserService.proxyuser.$MAPR_USER.groups</name>\n    <value>*</value>\n  </property>\n</configuration>|" $OOZIE_HOME/conf/oozie-site.xml
    fi
}

createRestartFile(){
  if ! [ -d ${MAPR_CONF_DIR}/restart ]; then
    mkdir -p ${MAPR_CONF_DIR}/restart
  fi

cat > "${MAPR_CONF_DIR}/restart/oozie-${OOZIE_VERSION}.restart" <<'EOF'
  #!/bin/bash
  isSecured="false"
  if [ -f "${MAPR_HOME}/conf/mapr-clusters.conf" ]; then
    isSecured=$(head -1 ${MAPR_HOME}/conf/mapr-clusters.conf | grep -o 'secure=\w*' | cut -d= -f2)
  fi
  if [ "${isSecured}" = "true" ] && [ -f "${MAPR_HOME}/conf/mapruserticket" ]; then
    export MAPR_TICKETFILE_LOCATION="${MAPR_HOME}/conf/mapruserticket"
    fi
  maprcli node services -action restart -name oozie -nodes $(hostname)
EOF

  chmod +x "${MAPR_CONF_DIR}/restart/oozie-$OOZIE_VERSION.restart"
  chown -R $MAPR_USER:$MAPR_GROUP "${MAPR_CONF_DIR}/restart/oozie-$OOZIE_VERSION.restart"

}

#
# Copying the warden service config file
#
setupWardenConfFile() {
  if ! [ -d ${MAPR_WARDEN_CONF_DIR} ]; then
    mkdir -p ${MAPR_WARDEN_CONF_DIR} > /dev/null 2>&1
  fi

  # Install warden file
  cp ${WARDEN_OOZIE_CONF} ${MAPR_WARDEN_CONF_DIR}
  chown $MAPR_USER:$MAPR_GROUP $WARDEN_OOZIE_DEST
}

extractSharelib(){
  if [ -f $OOZIE_HOME/oozie-sharelib-*.tar.gz  -a ! -d $OOZIE_HOME/share ]; then
      tar xfz $OOZIE_HOME/oozie-sharelib-*.tar.gz -C $OOZIE_HOME/
  fi
}

copyExtraLib(){
  if [ ! -f $OOZIE_HOME/libext/mysql* ]; then
      cp $MAPR_HOME/lib/mysql* $OOZIE_HOME/libext/
  fi
  if [ ! -f $OOZIE_HOME/share/lib/spark/maprbuildversion-*.jar ]; then
      find $OOZIE_HOME/share -maxdepth 0 -type d -exec cp $MAPR_HOME/lib/maprbuildversion-*.jar {}/lib/spark/ \;
  fi
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

extractSharelib
copyExtraLib
#build oozie war file
changeOoziePermission
configureClientImpersonation
if [ ! -f "$OOZIE_HOME/conf/.first_start" ]; then
    createRestartFile
fi
setupWardenConfFile

# remove state file and start files
if [ -f "$OOZIE_HOME/conf/.not_configured_yet" ]; then
    rm -f "$OOZIE_HOME/conf/.not_configured_yet"
fi

true