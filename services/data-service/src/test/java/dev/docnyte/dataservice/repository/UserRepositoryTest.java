package dev.docnyte.dataservice.repository;

import static org.assertj.core.api.Assertions.assertThat;

import dev.docnyte.dataservice.entity.User;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * Repository tests for UserRepository.
 *
 * <p>Uses @DataJpaTest for focused JPA testing with H2 in-memory database.
 */
@DataJpaTest
@ActiveProfiles("test")
class UserRepositoryTest {

  @Autowired private UserRepository userRepository;

  @BeforeEach
  void setUp() {
    // Clean database before each test
    userRepository.deleteAll();
  }

  @Test
  void findAll_ShouldReturnEmptyList_WhenNoUsers() {
    // Act
    List<User> users = userRepository.findAll();

    // Assert
    assertThat(users).isEmpty();
  }

  @Test
  void findAll_ShouldReturnAllUsers() {
    // Arrange
    User user1 = User.builder().name("John Doe").email("john@example.com").build();
    User user2 = User.builder().name("Jane Smith").email("jane@example.com").build();

    userRepository.save(user1);
    userRepository.save(user2);

    // Act
    List<User> users = userRepository.findAll();

    // Assert
    assertThat(users)
        .hasSize(2)
        .extracting(User::getName)
        .containsExactlyInAnyOrder("John Doe", "Jane Smith");
  }

  @Test
  void findById_ShouldReturnUser_WhenUserExists() {
    // Arrange
    User user = User.builder().name("John Doe").email("john@example.com").build();

    User savedUser = userRepository.save(user);

    // Act
    Optional<User> found = userRepository.findById(savedUser.getId());

    // Assert
    assertThat(found)
        .isPresent()
        .hasValueSatisfying(
            u -> {
              assertThat(u.getName()).isEqualTo("John Doe");
              assertThat(u.getEmail()).isEqualTo("john@example.com");
            });
  }

  @Test
  void findById_ShouldReturnEmpty_WhenUserDoesNotExist() {
    // Act
    Optional<User> found = userRepository.findById(999L);

    // Assert
    assertThat(found).isEmpty();
  }

  @Test
  void save_ShouldPersistUser() {
    // Arrange
    User user = User.builder().name("John Doe").email("john@example.com").build();

    // Act
    User savedUser = userRepository.save(user);

    // Assert
    assertThat(savedUser.getId()).isNotNull();
    assertThat(savedUser.getName()).isEqualTo("John Doe");
    assertThat(savedUser.getEmail()).isEqualTo("john@example.com");
  }

  @Test
  void save_ShouldGenerateId() {
    // Arrange
    User user = User.builder().name("John Doe").email("john@example.com").build();

    // Act
    User savedUser = userRepository.save(user);

    // Assert
    assertThat(savedUser.getId()).isNotNull().isPositive();
  }
}
