package org.apache.oozie.tools;
import com.mapr.web.security.SslConfig;
import com.mapr.web.security.WebSecurityManager;


public class OozieSSLVariablesCLI {

    public static void main(String[] args) throws Exception{
        System.exit(new OozieSSLVariablesCLI().run(args));
    }

    public synchronized int run(String[] args) throws Exception {
        if(args.length != 1 && args[0].isEmpty() ){
            System.err.println("Usage: org.apache.oozie.tools.OozieSSLVariablesCLI [keystoreFile | keystorePass]");
            return 1;
        }
        try (SslConfig sslConfig = WebSecurityManager.getSslConfig()) {
            switch (args [0]) {
                case "keystoreFile":
                    System.out.println(sslConfig.getClientKeystoreLocation());
                    break;
                case "keystorePass":
                    System.out.println(sslConfig.getClientKeystorePassword());
                    break;
                default:
                    System.err.println("Unknown option.");
                    return 1;
            }
        }
        return 0;
    }

}
