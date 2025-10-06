package dev.docnyte.dataservice.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.zalando.logbook.Logbook;

/**
 * Configuration for Logbook request/response logging.
 *
 * <p>Logbook is configured via application.yml, but this class can be used for programmatic
 * configuration if needed.
 *
 * <p>The current configuration (in application.yml):
 *
 * <ul>
 *   <li>Excludes actuator endpoints
 *   <li>Uses HTTP format style
 *   <li>Limits body size to 1000 characters
 *   <li>Obfuscates sensitive headers and parameters
 * </ul>
 */
@Configuration
public class LogbookConfig {

  /**
   * Create a Logbook bean with default configuration.
   *
   * <p>Configuration is primarily done in application.yml. This bean is created to ensure Logbook
   * is initialized.
   *
   * @return the Logbook instance
   */
  @Bean
  public Logbook logbook() {
    return Logbook.create();
  }
}
