package dev.docnyte.dataservice.controller;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import dev.docnyte.dataservice.entity.User;
import dev.docnyte.dataservice.repository.UserRepository;
import io.restassured.RestAssured;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.ActiveProfiles;

/**
 * Integration tests for DataController.
 *
 * <p>Uses REST Assured to test the complete flow from HTTP request to database with H2 in-memory
 * database.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class DataControllerIntegrationTest {

  @LocalServerPort private int port;

  @Autowired private UserRepository userRepository;

  @BeforeEach
  void setUp() {
    RestAssured.port = port;
    RestAssured.basePath = "/data";

    // Clean database before each test
    userRepository.deleteAll();
  }

  @Test
  void getAllUsers_ShouldReturnEmptyList_WhenNoUsers() {
    given()
        .when()
        .get("/users")
        .then()
        .statusCode(200)
        .contentType(ContentType.JSON)
        .body("$", hasSize(0));
  }

  @Test
  void getAllUsers_ShouldReturnAllUsers() {
    // Arrange
    User user1 = User.builder().name("John Doe").email("john@example.com").build();
    User user2 = User.builder().name("Jane Smith").email("jane@example.com").build();

    userRepository.save(user1);
    userRepository.save(user2);

    // Act & Assert
    given()
        .when()
        .get("/users")
        .then()
        .statusCode(200)
        .contentType(ContentType.JSON)
        .body("$", hasSize(2))
        .body("[0].name", equalTo("John Doe"))
        .body("[0].email", equalTo("john@example.com"))
        .body("[1].name", equalTo("Jane Smith"))
        .body("[1].email", equalTo("jane@example.com"));
  }

  @Test
  void getUserById_ShouldReturnUser_WhenUserExists() {
    // Arrange
    User user = User.builder().name("John Doe").email("john@example.com").build();

    User savedUser = userRepository.save(user);

    // Act & Assert
    given()
        .pathParam("id", savedUser.getId())
        .when()
        .get("/users/{id}")
        .then()
        .statusCode(200)
        .contentType(ContentType.JSON)
        .body("id", equalTo(savedUser.getId().intValue()))
        .body("name", equalTo("John Doe"))
        .body("email", equalTo("john@example.com"));
  }

  @Test
  void getUserById_ShouldReturn404_WhenUserNotFound() {
    // Act & Assert
    given()
        .pathParam("id", 999)
        .when()
        .get("/users/{id}")
        .then()
        .statusCode(404)
        .contentType(ContentType.JSON)
        .body("status", equalTo(404))
        .body("error", equalTo("Not Found"))
        .body("message", containsString("User not found with id: 999"));
  }
}
