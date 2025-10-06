package dev.docnyte.dataservice.controller;

import dev.docnyte.dataservice.dto.UserDTO;
import dev.docnyte.dataservice.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST controller for data operations.
 *
 * <p>Provides internal API endpoints for user data. These endpoints are called by the API service.
 */
@RestController
@RequestMapping("/data")
@RequiredArgsConstructor
@Slf4j
@Tag(name = "Data Service", description = "Internal data service API for fetching user data")
public class DataController {

  private final UserService userService;

  /**
   * Get all users from the database.
   *
   * @return list of all users
   */
  @GetMapping("/users")
  @Operation(
      summary = "Get all users",
      description = "Retrieve a list of all users from the PostgreSQL database")
  @ApiResponses({
    @ApiResponse(
        responseCode = "200",
        description = "Successfully retrieved users",
        content =
            @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = UserDTO.class)))
  })
  public ResponseEntity<List<UserDTO>> getAllUsers() {
    log.info("GET /data/users - Fetching all users");
    List<UserDTO> users = userService.getAllUsers();
    return ResponseEntity.ok(users);
  }

  /**
   * Get a user by ID.
   *
   * @param id the user ID
   * @return the user
   */
  @GetMapping("/users/{id}")
  @Operation(summary = "Get user by ID", description = "Retrieve a specific user by their ID")
  @ApiResponses({
    @ApiResponse(
        responseCode = "200",
        description = "Successfully retrieved user",
        content =
            @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = UserDTO.class))),
    @ApiResponse(responseCode = "404", description = "User not found")
  })
  public ResponseEntity<UserDTO> getUserById(
      @Parameter(description = "User ID", required = true) @PathVariable Long id) {
    log.info("GET /data/users/{} - Fetching user by id", id);
    UserDTO user = userService.getUserById(id);
    return ResponseEntity.ok(user);
  }
}
