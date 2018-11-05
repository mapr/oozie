package org.apache.oozie.tools;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;

public class OozieConfCLI {

    public static void main(String[] args) throws Exception {
        System.exit(new OozieConfCLI().run(args));
    }

    public synchronized int run(String[] args) throws Exception {
        if (args.length != 2 && args[0].isEmpty()) {
            System.err.println("Usage: org.apache.oozie.tools.OozieConfCLI [property] pathToConfiguration");
            return 1;
        }
        Configuration conf = new Configuration();
        conf.addResource(new Path(args[1]));
        System.out.println(conf.get(args[0]));
        return 0;
    }
}
