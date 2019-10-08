#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Set Jetty related environment variables
setup_jetty_log_and_pid() {
  if [ "${JETTY_OUT}" = "" ]; then
    export JETTY_OUT=${OOZIE_LOG}/jetty.out
    print "Setting JETTY_OUT:        ${JETTY_OUT}"
  else
    print "Using   JETTY_OUT:        ${JETTY_OUT}"
  fi

  if [ "${JETTY_PID_FILE}" = "" ]; then
    export JETTY_PID_FILE=${JETTY_DIR}/oozie.pid
    print "Setting JETTY_PID_FILE:        ${JETTY_PID_FILE}"
  else
    print "Using   JETTY_PID_FILE:        ${JETTY_PID_FILE}"
  fi
  ln -sf ${JETTY_PID_FILE} ${PID_LINK}
}

setup_java_opts() {
  if [ -z "${JAVA_HOME}" -a -z "${JRE_HOME}" ]; then
    if ${darwin}; then
      if [ -x '/usr/libexec/java_home' ] ; then
        export JAVA_HOME=`/usr/libexec/java_home`
      elif [ -d "/System/Library/Frameworks/JavaVM.framework/Versions/CurrentJDK/Home" ]; then
        export JAVA_HOME="/System/Library/Frameworks/JavaVM.framework/Versions/CurrentJDK/Home"
      fi
    else
      JAVA_PATH=`which java 2>/dev/null`
      if [ "x${JAVA_PATH}" != "x" ]; then
        JAVA_PATH=`dirname ${JAVA_PATH} 2>/dev/null`
      fi
      if [ "x${JRE_HOME}" = "x" ]; then
        if [ -x /usr/bin/java ]; then
          JRE_HOME=/usr
        fi
      fi
    fi
    if [ -z "${JAVA_HOME}" -a -z "${JRE_HOME}" ]; then
      echo "Neither the JAVA_HOME nor the JRE_HOME environment variable is defined"
      echo "At least one of these environment variable is needed to run this program"
      exit 1
    fi
  fi
  if [ -z "${JRE_HOME}" ]; then
    JRE_HOME="${JAVA_HOME}"
  fi

  JAVA_BIN="${JRE_HOME}"/bin/java
  echo "Using Java executable from ${JRE_HOME}"
}

setup_jetty_opts() {
  confDir="hadoop-conf"
  hadoopVersionFile=/opt/mapr/conf/hadoop_version
  if [ -f ${hadoopVersionFile} ]
  then
    hadoopVersion=`cat ${hadoopVersionFile} | grep yarn_version | cut -d '=' -f 2`
    confDir=/opt/mapr/hadoop/hadoop-${hadoopVersion}/etc/hadoop/
  else
    echo "Unknown hadoop version"
  fi
  echo "Using   JETTY_OPTS:       ${JETTY_OPTS}"
  jetty_opts="-Doozie.home.dir=${OOZIE_HOME}";
  jetty_opts="${jetty_opts} -Doozie.config.dir=${OOZIE_CONFIG}";
  jetty_opts="${jetty_opts} -Doozie.log.dir=${OOZIE_LOG}";
  jetty_opts="${jetty_opts} -Doozie.data.dir=${OOZIE_DATA}";
  jetty_opts="${jetty_opts} -Doozie.instance.id=${OOZIE_INSTANCE_ID}";
  jetty_opts="${jetty_opts} -Doozie.config.file=${OOZIE_CONFIG_FILE}";
  jetty_opts="${jetty_opts} -Doozie.log4j.file=${OOZIE_LOG4J_FILE}";
  jetty_opts="${jetty_opts} -Doozie.log4j.reload=${OOZIE_LOG4J_RELOAD}";
  # add required native libraries such as compression codecs
  jetty_opts="${jetty_opts} -Djava.library.path=${JAVA_LIBRARY_PATH}:/opt/mapr/lib";
  #MapR opts
  jetty_opts="${jetty_opts} -Dmapr.library.flatclass=true";
  jetty_opts="${jetty_opts} ${MAPR_ECOSYSTEM_SERVER_LOGIN_OPTS}";
  jetty_opts="${jetty_opts} -Dhadoop_conf_directory=${confDir}";
  jetty_opts="${jetty_opts} -Doozie_hostname=`hostname -f`";
  
  #JMX opts
  jetty_opts="${jetty_opts} -Dcom.sun.management.jmxremote"
  jetty_opts="${jetty_opts} -Dcom.sun.management.jmxremote.password.file=$MAPR_HOME/conf/jmxremote.password"
  jetty_opts="${jetty_opts} -Dcom.sun.management.jmxremote.access.file=$MAPR_HOME/conf/jmxremote.access"
  jetty_opts="${jetty_opts} -Dcom.sun.management.jmxremote.ssl=false"
  jetty_opts="${jetty_opts} -Dcom.sun.management.jmxremote.port=9010"

  # MapR Change: Set parameters in oozie-site.xml based on if MapR security is enabled or not
  if [ "$MAPR_SECURITY_STATUS" = "true" ]; then
    jetty_opts="${jetty_opts} -Dmapr_sec_type=org.apache.hadoop.security.authentication.server.MultiMechsAuthenticationHandler"
    jetty_opts="${jetty_opts} -Dmapr_sec_enabled=true"
    jetty_opts="${jetty_opts} -Dmapr_signature_secret=com.mapr.security.maprauth.MaprSignatureSecretFactory"
    jetty_opts="${jetty_opts} -Dhttps_enabled=true"
    jetty_opts="${jetty_opts} -Dcom.sun.management.jmxremote.authenticate=true"
    jetty_opts="${jetty_opts} -Dsecurity.headers.file=${BASEDIR}/conf/security-headers.xml"
  else
    jetty_opts="${jetty_opts} -Dmapr_sec_type=simple"
    jetty_opts="${jetty_opts} -Dmapr_sec_enabled=false"
    jetty_opts="${jetty_opts} -Dhttps_enabled=false"
    jetty_opts="${jetty_opts} -Dmapr_signature_secret=oozie"
    jetty_opts="${jetty_opts} -Dcom.sun.management.jmxremote.authenticate=false"
  fi

  jetty_opts="${jetty_opts} -cp ${JETTY_DIR}/*:${JETTY_DIR}/dependency/*:${BASEDIR}/lib/*:${BASEDIR}/libtools/*:${JETTY_DIR}/webapp/WEB-INF/classes/:${JETTY_DIR}"
  echo "Adding to JETTY_OPTS:     ${jetty_opts}"

  #MAPR-23180: cleanup old tmp files
  find /tmp/oozieTmp/ -maxdepth 1 -mtime +14 -exec rm -rf {} \; 2>/dev/null

  export JETTY_OPTS="${JETTY_OPTS} ${jetty_opts}"
}

start_jetty() {
  if [ ! -z "${JETTY_PID_FILE}" ]; then
    if [ -f "${JETTY_PID_FILE}" ]; then
      if [ -s "${JETTY_PID_FILE}" ]; then
        echo "Existing PID file found during start."
        if [ -r "${JETTY_PID_FILE}" ]; then
          PID=$(cat "${JETTY_PID_FILE}")
          ps -p "$PID" >/dev/null 2>&1
          if [ $? -eq 0 ] ; then
            echo "Oozie server appears to still be running with PID $PID. Start aborted."
            echo "If the following process is not a Jetty process, remove the PID file and try again:"
            ps -f -p "$PID"
            exit 1
          else
            echo "Removing/clearing stale PID file."
            rm -f "${JETTY_PID_FILE}" >/dev/null 2>&1
            if [ $? != 0 ]; then
              if [ -w "${JETTY_PID_FILE}" ]; then
                cat /dev/null > "${JETTY_PID_FILE}"
              else
                echo "Unable to remove or clear stale PID file. Start aborted."
                exit 1
              fi
            fi
          fi
        else
          echo "Unable to read PID file. Start aborted."
          exit 1
        fi
      else
        rm -f "$JETTY_PID_FILE" >/dev/null 2>&1
        if [ $? != 0 ]; then
          if [ ! -w "$JETTY_PID_FILE" ]; then
            echo "Unable to remove or write to empty PID file. Start aborted."
            exit 1
          fi
        fi
      fi
    fi
  fi

  if [ -f "${BASEDIR}/conf/.first_start" ]; then
    rm -f "${BASEDIR}/conf/.first_start"
  fi


  ${JAVA_BIN} ${JETTY_OPTS} org.apache.oozie.server.EmbeddedOozieServer >> "${JETTY_OUT}" 2>&1 &
  PID=$!
  if [ ${PID} ]; then
    echo -n "Oozie server started"
  fi

  if [ ! -z "${JETTY_PID_FILE}" ]; then
    echo -n $! > "${JETTY_PID_FILE}"
    echo -n " - PID: ${PID}."
  fi
  echo
}

run_jetty() {
  ${JAVA_BIN} ${JETTY_OPTS} org.apache.oozie.server.EmbeddedOozieServer
}

#TODO allow users to force kill jetty. Add --force
stop_jetty() {
  if [ ! -z "${JETTY_PID_FILE}" ]; then
    if [ -f "${JETTY_PID_FILE}" ]; then
      if [ -s "${JETTY_PID_FILE}" ]; then
        kill -0 "$(cat "${JETTY_PID_FILE}")" >/dev/null 2>&1
        if [ $? -gt 0 ]; then
          echo "PID file found but no matching process was found. Stop aborted."
          exit 1
        fi
      else
        echo "PID file is empty and has been ignored."
      fi
    else
      echo "\$JETTY_PID_FILE was set but the specified file does not exist. Is Oozie server running? Stop aborted."
      exit 1
    fi
  fi

  kill "$(cat "${JETTY_PID_FILE}")"

  RETRY_COUNT=5

  if [ ! -z "${JETTY_PID_FILE}" ]; then
    if [ -f "${JETTY_PID_FILE}" ]; then
      while [ $RETRY_COUNT -ge 0 ]; do
        kill -0 "$(cat ${JETTY_PID_FILE})" >/dev/null 2>&1
        if [ $? -gt 0 ]; then
          if [ -h "${PID_LINK}" ]; then
            rm -f ${PID_LINK}
          fi
          rm -f "${JETTY_PID_FILE}" >/dev/null 2>&1
          if [ $? != 0 ]; then
            if [ -w "${JETTY_PID_FILE}" ]; then
              cat /dev/null > "${JETTY_PID_FILE}"
            else
              echo "Oozie server stopped but the PID file could not be removed or cleared."
            fi
          fi
          break
        fi
        if [ ${RETRY_COUNT} -gt 0 ]; then
          sleep 1
        fi
        if [ ${RETRY_COUNT} -eq 0 ]; then
          echo "Oozie server did not stop in time. PID file was not removed."
        fi
        RETRY_COUNT=$((RETRY_COUNT - 1))
      done
    fi
  fi
}

prepare_sharelib() {
  # default share dir
  hadoop fs -test -d /oozie/share/lib
  if [ $? != 0 -o -f "${BASEDIR}/conf/.first_start" ] && [ -d ${BASEDIR}/share ]; then
    ${BASEDIR}/bin/oozie-setup.sh sharelib create -fs maprfs:/// -locallib ${BASEDIR}/share
  fi
}

jetty_main() {
  source ${BASEDIR}/bin/oozie-sys.sh
  # MapR change. Source env.sh if it exists
  if [[ -f ${BASEMAPR}/conf/env.sh ]]; then
    source ${BASEMAPR}/conf/env.sh
  fi
  JETTY_DIR=${BASEDIR}/embedded-oozie-server

  setup_jetty_log_and_pid
  setup_java_opts
  setup_jetty_opts

  actionCmd=$1
  case $actionCmd in
    (run)
       ${BASEDIR}/bin/oozie-setup.sh
       prepare_sharelib
       setup_ooziedb
       run_jetty
      ;;
    (start)
       ${BASEDIR}/bin/oozie-setup.sh
       prepare_sharelib
       setup_ooziedb
       start_jetty
      ;;
    (stop)
      stop_jetty
      ;;
    (status)
      if [ ! -z "$JETTY_PID_FILE" ]; then
        if [ -f "$JETTY_PID_FILE" ]; then
          if [ -s "$JETTY_PID_FILE" ]; then
            if [ -r "$JETTY_PID_FILE" ]; then
              PID=`cat "$JETTY_PID_FILE"`
              ps -p $PID >/dev/null 2>&1
              if [ $? -eq 0 ] ; then
                echo "JETTY is running with PID $PID."
                exit 0
              fi
            fi
          fi
        fi
      fi
      echo "Most likely JETTY is not running"
      exit 1
      ;;
  esac
}
