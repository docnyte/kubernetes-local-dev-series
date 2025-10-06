package dev.docnyte.dataservice.mapper;

import dev.docnyte.dataservice.dto.UserDTO;
import dev.docnyte.dataservice.entity.User;
import org.mapstruct.Mapper;

/**
 * MapStruct mapper for converting between User entity and UserDTO.
 *
 * <p>The componentModel = "spring" makes this mapper a Spring bean, allowing it to be injected into
 * other components.
 */
@Mapper(componentModel = "spring")
public interface UserMapper {

  /**
   * Converts User entity to UserDTO.
   *
   * @param user the user entity
   * @return the user DTO
   */
  UserDTO toDto(User user);

  /**
   * Converts UserDTO to User entity.
   *
   * @param userDTO the user DTO
   * @return the user entity
   */
  User toEntity(UserDTO userDTO);
}
