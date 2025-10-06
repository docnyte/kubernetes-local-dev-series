package dev.docnyte.dataservice.controller;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import dev.docnyte.dataservice.dto.UserDTO;
import dev.docnyte.dataservice.service.UserService;
import jakarta.persistence.EntityNotFoundException;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/** Unit tests for DataController. */
@WebMvcTest(DataController.class)
class DataControllerTest {

  @Autowired private MockMvc mockMvc;

  @MockBean private UserService userService;

  @Test
  void getAllUsers_ShouldReturnUserList() throws Exception {
    // Arrange
    List<UserDTO> users =
        Arrays.asList(
            UserDTO.builder().id(1L).name("John Doe").email("john@example.com").build(),
            UserDTO.builder().id(2L).name("Jane Smith").email("jane@example.com").build());

    when(userService.getAllUsers()).thenReturn(users);

    // Act & Assert
    mockMvc
        .perform(get("/data/users"))
        .andExpect(status().isOk())
        .andExpect(content().contentType(MediaType.APPLICATION_JSON))
        .andExpect(jsonPath("$[0].id").value(1))
        .andExpect(jsonPath("$[0].name").value("John Doe"))
        .andExpect(jsonPath("$[0].email").value("john@example.com"))
        .andExpect(jsonPath("$[1].id").value(2))
        .andExpect(jsonPath("$[1].name").value("Jane Smith"));
  }

  @Test
  void getUserById_ShouldReturnUser_WhenUserExists() throws Exception {
    // Arrange
    UserDTO user = UserDTO.builder().id(1L).name("John Doe").email("john@example.com").build();

    when(userService.getUserById(1L)).thenReturn(user);

    // Act & Assert
    mockMvc
        .perform(get("/data/users/1"))
        .andExpect(status().isOk())
        .andExpect(content().contentType(MediaType.APPLICATION_JSON))
        .andExpect(jsonPath("$.id").value(1))
        .andExpect(jsonPath("$.name").value("John Doe"))
        .andExpect(jsonPath("$.email").value("john@example.com"));
  }

  @Test
  void getUserById_ShouldReturn404_WhenUserNotFound() throws Exception {
    // Arrange
    when(userService.getUserById(999L))
        .thenThrow(new EntityNotFoundException("User not found with id: 999"));

    // Act & Assert
    mockMvc
        .perform(get("/data/users/999"))
        .andExpect(status().isNotFound())
        .andExpect(jsonPath("$.status").value(404))
        .andExpect(jsonPath("$.error").value("Not Found"));
  }
}
