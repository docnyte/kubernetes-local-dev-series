package dev.docnyte.dataservice.entity;

import jakarta.persistence.*;
import lombok.*;

/**
 * User entity mapped to the 'users' table in PostgreSQL.
 *
 * <p>Uses Lombok annotations to reduce boilerplate code for getters, setters, constructors, and
 * builder pattern.
 */
@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@ToString
public class User {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false, length = 100)
  private String name;

  @Column(nullable = false, unique = true, length = 100)
  private String email;
}
