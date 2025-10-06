package dev.docnyte.dataservice.repository;

import dev.docnyte.dataservice.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * Spring Data JPA repository for User entity.
 *
 * <p>Provides CRUD operations for User entities.
 */
@Repository
public interface UserRepository extends JpaRepository<User, Long> {}
