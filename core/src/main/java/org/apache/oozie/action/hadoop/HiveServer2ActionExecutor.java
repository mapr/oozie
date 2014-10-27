/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.oozie.action.hadoop;

import static org.apache.oozie.action.hadoop.LauncherMapper.CONF_OOZIE_ACTION_MAIN_CLASS;

import java.util.ArrayList;
import java.util.List;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.oozie.action.ActionExecutorException;
import org.apache.oozie.client.WorkflowAction;
import org.jdom.Element;
import org.jdom.JDOMException;
import org.jdom.Namespace;

public class HiveServer2ActionExecutor extends ScriptLanguageActionExecutor {

    private static final String HIVESERVER2_MAIN_CLASS_NAME = "org.apache.oozie.action.hadoop.HiveServer2Main";
    static final String HIVESERVER2_JDBC_URL = "oozie.hiveserver2.jdbc.url";
    static final String HIVESERVER2_PASSWORD = "oozie.hiveserver2.password";
    static final String HIVESERVER2_SCRIPT = "oozie.hiveserver2.script";
    static final String HIVESERVER2_PARAMS = "oozie.hiveserver2.params";
    static final String HIVESERVER2_ARGS = "oozie.hiveserver2.args";

    public HiveServer2ActionExecutor() {
        super("hiveserver2");
    }

    @Override
    public List<Class> getLauncherClasses() {
        List<Class> classes = new ArrayList<Class>();
        try {
            classes.add(Class.forName(HIVESERVER2_MAIN_CLASS_NAME));
        }
        catch (ClassNotFoundException e) {
            throw new RuntimeException("Class not found", e);
        }
        return classes;
    }

    @Override
    protected String getLauncherMain(Configuration launcherConf, Element actionXml) {
        return launcherConf.get(CONF_OOZIE_ACTION_MAIN_CLASS, HIVESERVER2_MAIN_CLASS_NAME);
    }

    @Override
    @SuppressWarnings("unchecked")
    Configuration setupActionConf(Configuration actionConf, Context context, Element actionXml,
                                  Path appPath) throws ActionExecutorException {
        Configuration conf = super.setupActionConf(actionConf, context, actionXml, appPath);
        Namespace ns = actionXml.getNamespace();

        String jdbcUrl = actionXml.getChild("jdbc-url", ns).getTextTrim();
        String password = actionXml.getChild("password", ns).getTextTrim();

        String script = actionXml.getChild("script", ns).getTextTrim();
        String scriptName = new Path(script).getName();
        String beelineScriptContent = context.getProtoActionConf().get(HIVESERVER2_SCRIPT);

        if (beelineScriptContent == null){
            addToCache(conf, appPath, script + "#" + scriptName, false);
        }

        List<Element> params = (List<Element>) actionXml.getChildren("param", ns);
        String[] strParams = new String[params.size()];
        for (int i = 0; i < params.size(); i++) {
            strParams[i] = params.get(i).getTextTrim();
        }
        String[] strArgs = null;
        List<Element> eArgs = actionXml.getChildren("argument", ns);
        if (eArgs != null && eArgs.size() > 0) {
            strArgs = new String[eArgs.size()];
            for (int i = 0; i < eArgs.size(); i++) {
                strArgs[i] = eArgs.get(i).getTextTrim();
            }
        }

        setHiveServer2Props(conf, jdbcUrl, password, scriptName, strParams, strArgs);
        return conf;
    }

    public static void setHiveServer2Props(Configuration conf, String jdbcUrl, String password, String script, String[] params,
                                           String[] args) {
        conf.set(HIVESERVER2_JDBC_URL, jdbcUrl);
        conf.set(HIVESERVER2_PASSWORD, password);
        conf.set(HIVESERVER2_SCRIPT, script);
        MapReduceMain.setStrings(conf, HIVESERVER2_PARAMS, params);
        MapReduceMain.setStrings(conf, HIVESERVER2_ARGS, args);
    }

    @Override
    protected boolean getCaptureOutput(WorkflowAction action) throws JDOMException {
        return false;
    }

    /**
     * Return the sharelib name for the action.
     *
     * @return returns <code>hive2</code>.
     * @param actionXml
     */
    @Override
    protected String getDefaultShareLibName(Element actionXml) {
        return "hive2";
    }

    @Override
    protected String getScriptName() {
        return HIVESERVER2_SCRIPT;
    }

}