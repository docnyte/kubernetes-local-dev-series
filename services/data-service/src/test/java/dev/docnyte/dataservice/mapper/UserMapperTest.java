package dev.docnyte.dataservice.mapper;

import static org.assertj.core.api.Assertions.assertThat;

import dev.docnyte.dataservice.dto.UserDTO;
import dev.docnyte.dataservice.entity.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * Tests for UserMapper.
 *
 * <p>Verifies MapStruct-generated mapper works correctly for entity-DTO conversions.
 */
@SpringBootTest
@ActiveProfiles("test")
class UserMapperTest {

  @Autowired private UserMapper userMapper;

  @Test
  void toDto_ShouldConvertEntityToDto() {
    // Arrange
    User user = User.builder().id(1L).name("John Doe").email("john@example.com").build();

    // Act
    UserDTO dto = userMapper.toDto(user);

    // Assert
    assertThat(dto).isNotNull();
    assertThat(dto.getId()).isEqualTo(1L);
    assertThat(dto.getName()).isEqualTo("John Doe");
    assertThat(dto.getEmail()).isEqualTo("john@example.com");
  }

  @Test
  void toDto_ShouldReturnNull_WhenEntityIsNull() {
    // Act
    UserDTO dto = userMapper.toDto(null);

    // Assert
    assertThat(dto).isNull();
  }

  @Test
  void toEntity_ShouldConvertDtoToEntity() {
    // Arrange
    UserDTO dto = UserDTO.builder().id(1L).name("John Doe").email("john@example.com").build();

    // Act
    User entity = userMapper.toEntity(dto);

    // Assert
    assertThat(entity).isNotNull();
    assertThat(entity.getId()).isEqualTo(1L);
    assertThat(entity.getName()).isEqualTo("John Doe");
    assertThat(entity.getEmail()).isEqualTo("john@example.com");
  }

  @Test
  void toEntity_ShouldReturnNull_WhenDtoIsNull() {
    // Act
    User entity = userMapper.toEntity(null);

    // Assert
    assertThat(entity).isNull();
  }

  @Test
  void toDto_ShouldHandleNullFields() {
    // Arrange
    User user = User.builder().id(null).name(null).email(null).build();

    // Act
    UserDTO dto = userMapper.toDto(user);

    // Assert
    assertThat(dto).isNotNull();
    assertThat(dto.getId()).isNull();
    assertThat(dto.getName()).isNull();
    assertThat(dto.getEmail()).isNull();
  }
}
