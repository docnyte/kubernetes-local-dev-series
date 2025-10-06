package dev.docnyte.dataservice;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.info.Info;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.env.Environment;

/**
 * Main Spring Boot application class for the Data Service.
 *
 * <p>This service provides internal data access layer for user management, connecting to PostgreSQL
 * and exposing REST API endpoints.
 */
@SpringBootApplication
@Slf4j
@OpenAPIDefinition(
    info =
        @Info(
            title = "Data Service API",
            version = "0.1.0",
            description =
                "Internal data service API for Kubernetes local development tutorial. "
                    + "Provides user management with PostgreSQL integration."))
public class DataServiceApplication {

  /**
   * Main method to start the Spring Boot application.
   *
   * @param args command line arguments
   */
  public static void main(String[] args) {
    SpringApplication.run(DataServiceApplication.class, args);
  }

  /**
   * Log application startup information.
   *
   * @param env the Spring environment
   */
  @EventListener(ApplicationReadyEvent.class)
  public void logStartup(ApplicationReadyEvent event) {
    Environment env = event.getApplicationContext().getEnvironment();
    String serverPort = env.getProperty("server.port", "8080");
    String appName = env.getProperty("spring.application.name", "data-service");

    log.info("=================================================");
    log.info("Application '{}' is running!", appName);
    log.info("Local: http://localhost:{}", serverPort);
    log.info("Swagger UI: http://localhost:{}/swagger-ui.html", serverPort);
    log.info("API Docs: http://localhost:{}/api-docs", serverPort);
    log.info("Actuator: http://localhost:{}/actuator/health", serverPort);
    log.info("=================================================");
  }
}
