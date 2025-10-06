package dev.docnyte.dataservice.service;

import dev.docnyte.dataservice.dto.UserDTO;
import dev.docnyte.dataservice.entity.User;
import dev.docnyte.dataservice.mapper.UserMapper;
import dev.docnyte.dataservice.repository.UserRepository;
import jakarta.persistence.EntityNotFoundException;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service layer for User operations.
 *
 * <p>Handles business logic and coordinates between the controller and repository layers.
 */
@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class UserService {

  private final UserRepository userRepository;
  private final UserMapper userMapper;

  /**
   * Get all users from the database.
   *
   * @return list of all users
   */
  public List<UserDTO> getAllUsers() {
    log.debug("Fetching all users");
    List<User> users = userRepository.findAll();
    if (log.isInfoEnabled()) {
      log.info("Found {} users", users.size());
    }
    return users.stream().map(userMapper::toDto).toList();
  }

  /**
   * Get a user by ID.
   *
   * @param id the user ID
   * @return the user DTO
   * @throws EntityNotFoundException if user not found
   */
  public UserDTO getUserById(Long id) {
    log.debug("Fetching user with id: {}", id);
    User user =
        userRepository
            .findById(id)
            .orElseThrow(() -> new EntityNotFoundException("User not found with id: " + id));
    if (log.isInfoEnabled()) {
      log.info("Found user: {}", user.getEmail());
    }
    return userMapper.toDto(user);
  }
}
