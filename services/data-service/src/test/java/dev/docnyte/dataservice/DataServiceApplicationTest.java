package dev.docnyte.dataservice;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * Application context test.
 *
 * <p>Verifies that the Spring Boot application starts successfully and all beans are loaded
 * correctly.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
@ActiveProfiles("test")
class DataServiceApplicationTest {

  @Test
  void contextLoads() {
    // This test will fail if the application context cannot be loaded
    // It verifies that all beans are properly configured and can be instantiated
  }
}
