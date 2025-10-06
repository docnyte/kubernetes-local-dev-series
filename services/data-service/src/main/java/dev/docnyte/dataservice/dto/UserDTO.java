package dev.docnyte.dataservice.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.*;

/**
 * Data Transfer Object for User entity.
 *
 * <p>Used for API request/response validation and to decouple the API layer from the persistence
 * layer.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@ToString
@Schema(description = "User information")
public class UserDTO {

  @Schema(description = "Unique user identifier", example = "1")
  private Long id;

  @NotBlank(message = "Name is required") @Size(min = 1, max = 100, message = "Name must be between 1 and 100 characters") @Schema(
      description = "User's full name",
      example = "John Doe",
      requiredMode = Schema.RequiredMode.REQUIRED)
  private String name;

  @NotBlank(message = "Email is required") @Email(message = "Email must be valid") @Size(max = 100, message = "Email must not exceed 100 characters") @Schema(
      description = "User's email address",
      example = "john.doe@example.com",
      requiredMode = Schema.RequiredMode.REQUIRED)
  private String email;
}
