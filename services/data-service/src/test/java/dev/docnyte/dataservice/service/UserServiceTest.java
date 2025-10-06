package dev.docnyte.dataservice.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import dev.docnyte.dataservice.dto.UserDTO;
import dev.docnyte.dataservice.entity.User;
import dev.docnyte.dataservice.mapper.UserMapper;
import dev.docnyte.dataservice.repository.UserRepository;
import jakarta.persistence.EntityNotFoundException;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/** Unit tests for UserService. */
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

  @Mock private UserRepository userRepository;

  @Mock private UserMapper userMapper;

  @InjectMocks private UserService userService;

  @Test
  void getAllUsers_ShouldReturnUserList() {
    // Arrange
    List<User> users =
        Arrays.asList(
            User.builder().id(1L).name("John Doe").email("john@example.com").build(),
            User.builder().id(2L).name("Jane Smith").email("jane@example.com").build());

    List<UserDTO> userDTOs =
        Arrays.asList(
            UserDTO.builder().id(1L).name("John Doe").email("john@example.com").build(),
            UserDTO.builder().id(2L).name("Jane Smith").email("jane@example.com").build());

    when(userRepository.findAll()).thenReturn(users);
    when(userMapper.toDto(users.get(0))).thenReturn(userDTOs.get(0));
    when(userMapper.toDto(users.get(1))).thenReturn(userDTOs.get(1));

    // Act
    List<UserDTO> result = userService.getAllUsers();

    // Assert
    assertEquals(2, result.size());
    assertEquals("John Doe", result.get(0).getName());
    assertEquals("Jane Smith", result.get(1).getName());
    verify(userRepository, times(1)).findAll();
  }

  @Test
  void getUserById_ShouldReturnUser_WhenUserExists() {
    // Arrange
    User user = User.builder().id(1L).name("John Doe").email("john@example.com").build();

    UserDTO userDTO = UserDTO.builder().id(1L).name("John Doe").email("john@example.com").build();

    when(userRepository.findById(1L)).thenReturn(Optional.of(user));
    when(userMapper.toDto(user)).thenReturn(userDTO);

    // Act
    UserDTO result = userService.getUserById(1L);

    // Assert
    assertNotNull(result);
    assertEquals("John Doe", result.getName());
    assertEquals("john@example.com", result.getEmail());
    verify(userRepository, times(1)).findById(1L);
  }

  @Test
  void getUserById_ShouldThrowException_WhenUserNotFound() {
    // Arrange
    when(userRepository.findById(999L)).thenReturn(Optional.empty());

    // Act & Assert
    assertThrows(EntityNotFoundException.class, () -> userService.getUserById(999L));
    verify(userRepository, times(1)).findById(999L);
  }
}
