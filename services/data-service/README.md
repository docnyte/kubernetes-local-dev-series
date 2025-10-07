# Data Service (Java Spring Boot)

Java Spring Boot service that provides the internal data access layer for the Kubernetes local development tutorial. This service connects to PostgreSQL and handles user data operations.

## Features

- **Spring Boot 3.5.6**: Modern Java framework with auto-configuration
- **Java 21**: Latest LTS version with modern language features
- **JPA/Hibernate**: Object-relational mapping for PostgreSQL
- **Lombok**: Reduces boilerplate code with annotations
- **MapStruct**: Type-safe bean mapping
- **SpringDoc OpenAPI**: Automatic API documentation generation
- **Logbook**: Simple request/response logging
- **Actuator**: Health checks and metrics endpoints
- **Comprehensive Tests**: JUnit 5 with Mockito
- **Code Quality**: Spotless (Google Java Format), SpotBugs, PMD
- **Docker Ready**: Multi-stage Dockerfile optimized for production

## Architecture

```
API Service (FastAPI) → Data Service (Spring Boot) → PostgreSQL (Docker)
```

The Data Service:
- Provides internal ClusterIP endpoints (not exposed via Ingress)
- Connects to external PostgreSQL running in Docker
- Fetches user data from the database
- Provides health checks for monitoring

## API Endpoints

### Internal API (ClusterIP only)

- `GET /data/users` - List all users from PostgreSQL
- `GET /data/users/{id}` - Get user by ID from PostgreSQL
- `GET /actuator/health` - Health check endpoint
- `GET /swagger-ui.html` - Interactive API documentation
- `GET /api-docs` - OpenAPI specification

## Technology Stack

- **Java**: 21 (LTS)
- **Framework**: Spring Boot 3.5.6
- **Database**: PostgreSQL (via JPA/Hibernate)
- **Libraries**:
  - Lombok 1.18.36 (code generation)
  - MapStruct 1.6.3 (bean mapping)
  - SpringDoc 2.7.0 (OpenAPI docs)
  - Logbook 3.9.0 (request/response logging)
- **Build Tool**: Maven
- **Code Quality**:
  - Spotless 2.44.0 (Google Java Format)
  - SpotBugs 4.8.6.4 (static analysis)
  - PMD 3.26.0 (code quality)
- **Testing**: JUnit 5, Mockito, Spring Boot Test

## Development Setup

### Prerequisites

- Java 21+
- Maven 3.6+
- Docker (optional, for containerized builds)
- PostgreSQL running externally (see `external/postgres/`)

### Quick Start with Make

The project includes a Makefile for common development tasks:

```bash
# View all available commands
make help

# Install dependencies and run checks
make install      # Download dependencies
make check        # Run linting, formatting, and tests
make run          # Run the application locally
```

### Install Dependencies

```bash
# Using make (recommended)
make install

# Or using Maven directly
mvn dependency:go-offline -B
```

### Run Locally

**Important**: You must have PostgreSQL running before starting the service.

```bash
# Start PostgreSQL (from project root)
cd external/postgres
docker-compose up -d
cd ../../services/data-service

# Run the service using make
make run

# Or using Maven directly
mvn spring-boot:run
```

The API will be available at http://localhost:8080

### Environment Variables

Set these environment variables or use defaults:

```env
DB_HOST=host.docker.internal     # PostgreSQL host
DB_PORT=5432                      # PostgreSQL port
DB_NAME=devdb                     # Database name
DB_USERNAME=postgres              # Database username
DB_PASSWORD=postgres              # Database password
SERVER_PORT=8080                  # Application port
LOG_LEVEL=INFO                    # Logging level (DEBUG, INFO, WARNING, ERROR)
```

### Run Tests

```bash
# Using make (recommended)
make test           # Run all tests
make test-cov       # Run with coverage report

# Or using Maven directly
mvn test
mvn test jacoco:report
```

### Code Formatting and Linting

The project uses Spotless (Google Java Format), SpotBugs, and PMD for code quality.

```bash
# Using make (recommended)
make format         # Format code with Spotless
make lint           # Run all linting checks
make check          # Run linting + tests
make validate       # Format code + run all checks

# Or using Maven directly
mvn spotless:apply          # Format code
mvn spotless:check          # Check formatting
mvn spotbugs:check          # Run SpotBugs
mvn pmd:check               # Run PMD
```

### Generate Quality Reports

```bash
# SpotBugs HTML report
make spotbugs-report
# Report: target/spotbugsXml.xml

# PMD HTML report
make pmd-report
# Report: target/site/pmd.html
```

## Docker

The Dockerfile includes a multi-stage build with an optional `lint` stage for quality checks in CI/CD.

### Build Production Image

```bash
# Using make
make build

# Or using docker directly
docker build -t data-service:latest .
```

### Build with Quality Checks (Lint Stage)

The `lint` stage runs Spotless, SpotBugs, PMD, and tests in a containerized environment:

```bash
# Using make (recommended for CI/CD)
make build-lint

# Or using docker directly
docker build --target=lint -t data-service:lint .
```

**What the lint stage does:**
- ✅ Runs `spotless:check` for formatting
- ✅ Runs `spotbugs:check` for static analysis
- ✅ Runs `pmd:check` for code quality
- ✅ Runs `mvn test` for all tests
- ✅ Fails the build if any check fails

**Best Practice**: Run `make build-lint` in your CI/CD pipeline before building the production image.

### Run Container

```bash
docker run -p 8080:8080 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=devdb \
  -e DB_USERNAME=postgres \
  -e DB_PASSWORD=postgres \
  data-service:latest
```

## Project Structure

```
data-service/
├── src/
│   ├── main/
│   │   ├── java/com/example/dataservice/
│   │   │   ├── DataServiceApplication.java    # Main application class
│   │   │   ├── config/
│   │   │   │   └── LogbookConfig.java         # Request/response logging config
│   │   │   ├── controller/
│   │   │   │   └── DataController.java        # REST endpoints
│   │   │   ├── dto/
│   │   │   │   └── UserDTO.java               # Data transfer object
│   │   │   ├── entity/
│   │   │   │   └── User.java                  # JPA entity
│   │   │   ├── exception/
│   │   │   │   └── GlobalExceptionHandler.java # Exception handling
│   │   │   ├── mapper/
│   │   │   │   └── UserMapper.java            # MapStruct mapper
│   │   │   ├── repository/
│   │   │   │   └── UserRepository.java        # JPA repository
│   │   │   └── service/
│   │   │       └── UserService.java           # Business logic
│   │   └── resources/
│   │       └── application.yml                # Configuration
│   └── test/
│       └── java/com/example/dataservice/
│           ├── controller/
│           │   └── DataControllerTest.java    # Controller tests
│           └── service/
│               └── UserServiceTest.java       # Service tests
├── Dockerfile                                  # Multi-stage Docker build
├── Makefile                                    # Development commands
├── pom.xml                                     # Maven configuration
├── spotbugs-exclude.xml                        # SpotBugs exclusions
└── README.md                                   # This file
```

## Code Quality

### Lombok

Reduces boilerplate code with annotations:

```java
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {
    private Long id;
    private String name;
    private String email;
}
```

### MapStruct

Type-safe bean mapping:

```java
@Mapper(componentModel = "spring")
public interface UserMapper {
    UserDTO toDto(User user);
    User toEntity(UserDTO userDTO);
}
```

### Request/Response Logging

Logbook automatically logs all HTTP requests and responses:

```
Incoming Request: GET /data/users
Remote: 127.0.0.1

Outgoing Response: 200 OK
Content-Type: application/json
[{"id":1,"name":"John Doe","email":"john@example.com"}]
```

Configuration in `application.yml`:
- **Excludes**: `/actuator/**` endpoints to prevent health check spam
- **Obfuscates**: Sensitive headers (Authorization) and parameters (passwords)
- **DispatcherServlet**: Set to WARN level to reduce request logging noise

## Kubernetes Deployment

This service is designed to run in Kubernetes with:

- **Service Type**: ClusterIP (internal only)
- **Health Check**: `/actuator/health` for liveness/readiness probes
- **Database Connection**: External PostgreSQL via `host.docker.internal`
- **Resource Limits**: Configured in K8s manifests
- **Environment**: Config via ConfigMap/Secrets
- **Logging**: Actuator health endpoints excluded from Logbook logging; DispatcherServlet set to WARN

See the `k3d-setup/`, `minikube-setup/`, or `kind-setup/` directories for Kubernetes manifests.

### Logging Configuration

The service uses structured logging with health check filtering:

- **Application logs**: Controlled via `LOG_LEVEL` environment variable (DEBUG, INFO, WARNING, ERROR)
- **Logbook**: Request/response logging with actuator endpoints excluded
- **Spring DispatcherServlet**: Set to WARN level to reduce noise from health check requests
- **Health checks**: K8s liveness/readiness probes hit `/actuator/health/*` every 5-10 seconds

## Development Workflow

### Before Committing

Always run quality checks before committing:

```bash
make validate       # Format code + run all checks
```

Or individually:

```bash
make format         # Format code
make check          # Run linting, formatting, and tests
```

### CI/CD Integration

In your CI/CD pipeline, run the Docker lint stage:

```bash
# Example GitHub Actions / GitLab CI
make build-lint     # Run quality checks in Docker
make build          # Build production image if checks pass
```

This ensures code quality without requiring CI runners to have Java/Maven installed.

## Database Schema

The `users` table is automatically created/updated by Hibernate:

```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE
);
```

## Troubleshooting

### Cannot connect to PostgreSQL

Ensure PostgreSQL is running:

```bash
cd external/postgres
docker-compose ps
```

Check the connection string in `application.yml`:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://host.docker.internal:5432/devdb
```

### Spotless formatting failures

Auto-fix formatting issues:

```bash
make format
```

### SpotBugs or PMD violations

View detailed reports:

```bash
make spotbugs-report   # target/spotbugsXml.xml
make pmd-report        # target/site/pmd.html
```

## License

This is an educational project for the Kubernetes local development blog series.
