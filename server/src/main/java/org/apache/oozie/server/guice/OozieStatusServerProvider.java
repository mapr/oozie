package org.apache.oozie.server.guice;

import com.google.inject.Inject;
import com.google.inject.Provider;
import org.apache.hadoop.conf.Configuration;
import org.apache.oozie.server.OozieStatusServer;
import org.apache.oozie.service.ConfigurationService;
import org.apache.oozie.service.Services;

public class OozieStatusServerProvider implements Provider<OozieStatusServer> {

  public static final String OOZIE_STATUS_SERVER_ENABLED = "oozie.status.server.enabled";
  public static final String OOZIE_STATUS_SERVER_HOSTNAME = "oozie.status.server.hostname";
  public static final String OOZIE_STATUS_SERVER_PORT = "oozie.status.server.port";

  private final Configuration oozieConfiguration;

  @Inject
  public OozieStatusServerProvider(final Services oozieServices) {
    oozieConfiguration = oozieServices.get(ConfigurationService.class).getConf();
  }

  @Override
  public OozieStatusServer get() {
    boolean enabled = oozieConfiguration.getBoolean(OOZIE_STATUS_SERVER_ENABLED, true);
    int httpPort = oozieConfiguration.getInt(OOZIE_STATUS_SERVER_PORT, 21443);
    String hostname = oozieConfiguration.get(OOZIE_STATUS_SERVER_HOSTNAME, "localhost");

    return new OozieStatusServer(enabled, httpPort, hostname);
  }
}
