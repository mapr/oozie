#!/bin/bash

MAPR_HOME=${MAPR_HOME:-/opt/mapr}
OOZIE_VERSION=`cat $MAPR_HOME/oozie/oozieversion`
OOZIE_HOME="$MAPR_HOME"/oozie/oozie-"$OOZIE_VERSION"
JETTY_LIB_DIR="${OOZIE_HOME}"/embedded-oozie-server/webapp/WEB-INF/lib/
OOZIE_BIN="$OOZIE_HOME"/bin
MAPR_CONF_DIR="${MAPR_HOME}/conf/"
MAPR_WARDEN_CONF_DIR="${MAPR_HOME}/conf/conf.d"
DAEMON_CONF="$MAPR_HOME/conf/daemon.conf"
WARDEN_OOZIE_CONF="$OOZIE_HOME"/conf/warden.oozie.conf
WARDEN_OOZIE_DEST="$MAPR_WARDEN_CONF_DIR/warden.oozie.conf"
OOZIE_TMP_DIR=/tmp/oozieTmp
HADOOP_VER=$(cat "$MAPR_HOME/hadoop/hadoopversion")
HADOOP_HOME="$MAPR_HOME/hadoop/hadoop-$HADOOP_VER"
secureCluster=0
clientNode=0
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
  findAndCopyJar "$MAPR_HOME/lib" "$OOZIE_HOME/share/lib/oozie" -name "mapr-ojai-driver-*.jar" -not -name "*tests*.jar"
  findAndCopyJar "${HADOOP_HOME}" "$OOZIE_HOME/share/lib/spark" -name "hadoop-common*.jar" -not -name "*tests*.jar"
}

configureOozieJMX() {
  if ! grep -q org.apache.oozie.service.MetricsInstrumentationService $OOZIE_HOME/conf/oozie-site.xml; then
    sed -i -e 's/<\/configuration>/    <property>\n        <name>oozie.services.ext<\/name>\n        <value>\n          org.apache.oozie.service.MetricsInstrumentationService\n        <\/value>\n    <\/property>\n\n<\/configuration>/' \
    $OOZIE_HOME/conf/oozie-site.xml
  fi
}

findAndCopyJar() {
   local sourceDir="${1}"
   local targetDir="${2}"
   shift 2
   local filters="$@"
   foundJar="$(find -H ${sourceDir} ${filters} -name "*[.0-9].jar" -print -quit)"
   test -z "$foundJar" && foundJar="$(find -H ${sourceDir} ${filters} -name "*[.0-9].jar" -print -quit)"
   test -z "$foundJar" && foundJar="$(find -H ${sourceDir} ${filters} -name "*SNAPSHOT.jar" -print -quit)"
   test -z "$foundJar" && foundJar="$(find -H ${sourceDir} ${filters} -name "*beta.jar" -print -quit)"
   test -z "$foundJar" && foundJar="$(find -H ${sourceDir} ${filters} -name "*[a-z].jar" -print -quit)"
   if [ -z "${foundJar}" ]; then
         echo "File by filters '${filters}' not found in '${sourceDir}'" 1>&2
         return 1
   fi

   find "$targetDir" ${filters} -delete
   cp "${foundJar}" "$targetDir"
}

copyMaprLibs() {
  test -e ${OOZIE_HOME}/lib || ln -s ${JETTY_LIB_DIR} ${OOZIE_HOME}/lib

  # move all hadoop jars
  local suffix="-[0-9.]*"
  local hadoopJars="hadoop-mapreduce-client-contrib${suffix}.jar:hadoop-mapreduce-client-core${suffix}.jar:hadoop-mapreduce-client-common${suffix}.jar:hadoop-mapreduce-client-jobclient${suffix}.jar:hadoop-mapreduce-client-app${suffix}.jar:hadoop-yarn-common${suffix}.jar:hadoop-yarn-api${suffix}.jar:hadoop-yarn-client${suffix}.jar:hadoop-hdfs${suffix}.jar:hadoop-common${suffix}.jar:hadoop-auth${suffix}.jar:commons-configuration-*.jar"
  for jar in ${hadoopJars//:/$'\n'}; do
    findAndCopyJar "${HADOOP_HOME}" "${JETTY_LIB_DIR}" -iname "${jar}" || exit -1
  done

  # move mapr jars if available
  findAndCopyJar "${MAPR_HOME}/lib" "${JETTY_LIB_DIR}" -iname "JPam-[0-9].*.jar" 2> /dev/null
  findAndCopyJar "${MAPR_HOME}/lib" "${JETTY_LIB_DIR}" -iname "zookeeper-[0-9].*.jar" 2> /dev/null
  findAndCopyJar "${MAPR_HOME}/lib" "${JETTY_LIB_DIR}" -iname "zookeeper-jute-[0-9].*.jar" 2> /dev/null
  findAndCopyJar "${MAPR_HOME}/lib" "${JETTY_LIB_DIR}" -iname "maprfs-[0-9].*jar" -not -name "*test*.jar" 2> /dev/null
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
        #Parse Common options
        #Ingore ones we don't care about
        ecOpts=($2)
        shift 2
        restOpts="$@"
        eval set -- "${ecOpts[@]} --"
        while (($#)); do
          case "$1" in
            --client | -c)
              clientNode=1
              shift 1
              ;;
            *)
              #echo "Ignoring common option $j"
              shift 1
              ;;
          esac
        done
        shift 2
        eval set -- "$restOpts"
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

if [ "$secureCluster" == "1" ] && [ "$clientNode" == "1" ]; then
  sed -i '/OOZIE_CLIENT_OPTS/s/^#*//g' ${OOZIE_HOME}/conf/oozie-client-env.sh
fi

extractSharelib
copyExtraLib
copyMaprLibs
#build oozie war file
changeOoziePermission
configureOozieJMX
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
