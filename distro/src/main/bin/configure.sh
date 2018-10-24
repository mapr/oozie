#!/bin/bash

MAPR_HOME=${MAPR_HOME:-/opt/mapr}
OOZIE_VERSION="4.3.0"
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

if [ -f "$DAEMON_CONF" ]; then
  MAPR_USER=$( awk -F = '$1 == "mapr.daemon.user" { print $2 }' "$DAEMON_CONF")
  MAPR_GROUP=$( awk -F = '$1 == "mapr.daemon.group" { print $2 }' "$DAEMON_CONF")
else
  MAPR_USER=`logname`
  MAPR_GROUP="$MAPR_USER"
fi

changeOoziePermission() {
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
  find $OOZIE_HOME/conf \( -name "oozie-site.xml*" -o -name "oozie-env.sh*" \) \
      -exec bash -c 'chmod 600 {}' \;
  chmod 700 -R "$OOZIE_HOME/conf/action-conf"
}

configDefaultSsl() {
  #enable SSL if ssl was disabled and cluster is secure
  sed -i '/OOZIE_HTTPS_KEYSTORE_FILE/s/^#*//g' $OOZIE_HOME/conf/oozie-env.sh
  sed -i '/OOZIE_HTTPS_KEYSTORE_PASS/s/^#*//g' $OOZIE_HOME/conf/oozie-env.sh
  sed -i '/OOZIE_HTTPS_PORT/s/^#*//g' $OOZIE_HOME/conf/oozie-env.sh
  sed -i '/OOZIE_CLIENT_OPTS/s/^#*//g' $OOZIE_HOME/conf/oozie-client-env.sh
  echo "true" > "$OOZIE_HOME/conf/ooziessl"
}

disableSsl(){
  sed -i '/OOZIE_HTTPS_KEYSTORE_FILE/s/^#*/#/g' $OOZIE_HOME/conf/oozie-env.sh
  sed -i '/OOZIE_HTTPS_KEYSTORE_PASS/s/^#*/#/g' $OOZIE_HOME/conf/oozie-env.sh
  sed -i '/OOZIE_HTTPS_PORT/s/^#*/#/g' $OOZIE_HOME/conf/oozie-env.sh
  echo "false" > "$OOZIE_HOME/conf/ooziessl"
}

configureClientImpersonation() {
    if ! grep -q oozie.service.ProxyUserService.proxyuser.$MAPR_USER.hosts $OOZIE_HOME/conf/oozie-site.xml; then
        sed -i -e "s|</configuration>|  <property>\n    <name>oozie.service.ProxyUserService.proxyuser.$MAPR_USER.hosts</name>\n    <value>*</value>\n  </property>\n</configuration>|" $OOZIE_HOME/conf/oozie-site.xml
    fi
    if ! grep -q oozie.service.ProxyUserService.proxyuser.$MAPR_USER.groups $OOZIE_HOME/conf/oozie-site.xml; then
        sed -i -e "s|</configuration>|  <property>\n    <name>oozie.service.ProxyUserService.proxyuser.$MAPR_USER.groups</name>\n    <value>*</value>\n  </property>\n</configuration>|" $OOZIE_HOME/conf/oozie-site.xml
    fi
}

#
# Build Oozie war
#
buildOozieWar() {
  #remove old war packaging dir
  rm -rf ${OOZIE_TMP_DIR}/oozie-war-packing-*
  OOZIE_SSL=$(cat "$OOZIE_HOME/conf/ooziessl")
  # Constructing the oozie-setup command.
  if [ "$OOZIE_SSL" == true ]; then
    cmd="$OOZIE_HOME/bin/oozie-setup.sh -hadoop "${HADOOP_VER}" "${MAPR_HOME}/hadoop/hadoop-${HADOOP_VER}" -secure"
  else
    cmd="$OOZIE_HOME/bin/oozie-setup.sh -hadoop "${HADOOP_VER}" "${MAPR_HOME}/hadoop/hadoop-${HADOOP_VER}
  fi
  $cmd > /dev/null
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
  checkWardenPort
}


checkWardenPort() {
  OOZIE_SSL=$(cat "$OOZIE_HOME/conf/ooziessl")
  if [ "$OOZIE_SSL" == true ]; then
      sed -i 's/\(service.port=\)\(.*\)/\111443/' $WARDEN_OOZIE_DEST
      sed -i 's/\(service.ui.port=\)\(.*\)/\111443/' $WARDEN_OOZIE_DEST
  else
      sed -i 's/\(service.port=\)\(.*\)/\111000/' $WARDEN_OOZIE_DEST
      sed -i 's/\(service.ui.port=\)\(.*\)/\111000/' $WARDEN_OOZIE_DEST
  fi
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
  if [ ! -f $OOZIE_HOME/utils/oozie-hadoop-utils-hadoop*.jar ]; then
    cp $OOZIE_HOME/share/lib/oozie/oozie-hadoop-utils-hadoop*.jar $OOZIE_HOME/utils
  fi
}


#
# main
#
# typically called from core configure.sh
#

USAGE="usage: $0 [--secure|--customSecure|--unsecure|-EC|-R|--help]"
if [ ${#} -gt 1 ]; then
  for i in "$@" ; do
    case "$i" in
      --secure)
        secureCluster=1
        if [ -f "$OOZIE_HOME/conf/.custom_ssl_config" ]; then
          rm -f "$OOZIE_HOME/conf/.custom_ssl_config"
        fi
        configDefaultSsl
        shift
        ;;
      --customSecure|-cs)
        secureCluster=1
        touch "$OOZIE_HOME/conf/.custom_ssl_config"
        if [ -f "$OOZIE_HOME/conf/.not_configured_yet" ]; then
          configDefaultSsl
        fi
        shift
        ;;
      --unsecure)
        secureCluster=0
        disableSsl
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
buildOozieWar
changeOoziePermission
configureClientImpersonation
if [ ! -f "$OOZIE_HOME/conf/.first_start" ]; then
    createRestartFile
fi
setupWardenConfFile

# remove state and start files
if [ -f "$OOZIE_HOME/conf/.not_configured_yet" ]; then
    rm -f "$OOZIE_HOME/conf/.not_configured_yet"
fi

true