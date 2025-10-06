# Multi-stage Dockerfile for Java Spring Boot service using Maven

# =============================================================================
# Lint Stage (Optional - for CI/CD quality checks)
# Build with: docker build --target=lint -t data-service:lint .
# =============================================================================
FROM eclipse-temurin:21-jdk-alpine AS lint

# Install Maven
RUN apk add --no-cache maven

# Set working directory
WORKDIR /app

# Copy pom.xml and spotbugs-exclude.xml
COPY pom.xml spotbugs-exclude.xml ./

# Download dependencies (cached layer)
RUN mvn dependency:go-offline -B

# Copy source code and tests
COPY src/ ./src/

# Run code quality checks and tests
RUN echo "Running Spotless formatting check..." && \
    mvn spotless:check && \
    echo "✓ Formatting passed" && \
    echo "Running SpotBugs static analysis..." && \
    mvn spotbugs:check && \
    echo "✓ SpotBugs passed" && \
    echo "Running PMD code quality check..." && \
    mvn pmd:check && \
    echo "✓ PMD passed" && \
    echo "Running tests..." && \
    mvn test && \
    echo "✓ All tests passed" && \
    echo "✓ Quality checks complete!"

# =============================================================================
# Builder Stage (Build JAR)
# =============================================================================
FROM eclipse-temurin:21-jdk-alpine AS builder

# Install Maven
RUN apk add --no-cache maven

# Set working directory
WORKDIR /app

# Copy pom.xml and spotbugs-exclude.xml
COPY pom.xml spotbugs-exclude.xml ./

# Download dependencies (cached layer)
RUN mvn dependency:go-offline -B

# Copy source code (no tests)
COPY src/main/ ./src/main/

# Build the application (skip tests, already ran in lint stage)
RUN mvn clean package -DskipTests -B

# =============================================================================
# Production Stage (Final minimal image)
# =============================================================================
FROM eclipse-temurin:21-jre-alpine

# Set working directory
WORKDIR /app

# Copy JAR from builder
COPY --from=builder /app/target/*.jar app.jar

# Create non-root user
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Set environment variables
ENV JAVA_OPTS="-Xms256m -Xmx512m" \
    SERVER_PORT=8080

# Expose application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
