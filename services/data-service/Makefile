.PHONY: help install clean test format lint check build build-lint run package

# Default target
help:
	@echo "Available commands:"
	@echo "  make install      - Install dependencies"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make test         - Run tests"
	@echo "  make format       - Format code with Spotless"
	@echo "  make lint         - Run linting checks (Spotless, SpotBugs, PMD)"
	@echo "  make check        - Run all quality checks (lint + test)"
	@echo "  make package      - Build JAR package"
	@echo "  make build        - Build production Docker image"
	@echo "  make build-lint   - Build and run lint stage in Docker"
	@echo "  make run          - Run application locally"

# Install dependencies
install:
	mvn dependency:go-offline -B

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@mvn clean
	@echo "✓ Clean complete"

# Run tests
test:
	@echo "Running tests..."
	@mvn test
	@echo "✓ Tests passed"

# Run tests with coverage
test-cov:
	@echo "Running tests with coverage..."
	@mvn test jacoco:report
	@echo "✓ Coverage report generated in target/site/jacoco/index.html"

# Format code
format:
	@echo "Formatting code with Spotless..."
	@mvn spotless:apply
	@echo "✓ Code formatted"

# Run linting checks
lint:
	@echo "Running Spotless formatting check..."
	@mvn spotless:check
	@echo "✓ Formatting passed"
	@echo "Running SpotBugs static analysis..."
	@mvn spotbugs:check
	@echo "✓ SpotBugs passed"
	@echo "Running PMD code quality check..."
	@mvn pmd:check
	@echo "✓ PMD passed"

# Run all quality checks
check: lint test
	@echo "✓ All quality checks passed!"

# Build JAR package
package:
	@echo "Building JAR package..."
	@mvn clean package -DskipTests
	@echo "✓ Package built: target/data-service-0.1.0.jar"

# Build production Docker image
build:
	@echo "Building production Docker image..."
	@docker build -t data-service:latest .
	@echo "✓ Docker image built: data-service:latest"

# Build and run lint stage (quality checks in Docker)
build-lint:
	@echo "Building lint stage..."
	@docker build --target=lint -t data-service:lint .
	@echo "✓ Docker lint stage passed!"

# Run application locally
run:
	@echo "Starting application..."
	@mvn spring-boot:run

# Run application with specific port
run-port:
	@echo "Starting application on port ${PORT}..."
	@mvn spring-boot:run -Dspring-boot.run.arguments="--server.port=${PORT}"

# Validate everything before commit
validate: format check
	@echo "✓ Ready to commit!"

# Generate SpotBugs HTML report
spotbugs-report:
	@echo "Generating SpotBugs HTML report..."
	@mvn spotbugs:spotbugs
	@echo "✓ Report generated in target/spotbugsXml.xml"

# Generate PMD HTML report
pmd-report:
	@echo "Generating PMD HTML report..."
	@mvn pmd:pmd
	@echo "✓ Report generated in target/site/pmd.html"
