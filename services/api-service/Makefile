.PHONY: help install dev test lint format check build build-lint run clean

# Default target
help:
	@echo "Available commands:"
	@echo "  make install      - Install production dependencies"
	@echo "  make dev          - Install all dependencies (including dev)"
	@echo "  make test         - Run tests"
	@echo "  make lint         - Run linting checks"
	@echo "  make format       - Format code"
	@echo "  make check        - Run all quality checks (lint + format + test)"
	@echo "  make build        - Build production Docker image"
	@echo "  make build-lint   - Build and run lint stage in Docker"
	@echo "  make run          - Run application locally"
	@echo "  make clean        - Remove cache and build artifacts"

# Install production dependencies only
install:
	uv sync

# Install all dependencies including dev
dev:
	uv sync --all-extras

# Run tests
test:
	uv run pytest -v

# Run tests with coverage
test-cov:
	uv run pytest --cov=app --cov-report=html --cov-report=term

# Run linting checks
lint:
	@echo "Running ruff linting checks..."
	@uv run ruff check app/ tests/
	@echo "✓ Linting passed"

# Format code
format:
	@echo "Formatting code with ruff..."
	@uv run ruff format app/ tests/
	@echo "✓ Code formatted"

# Auto-fix linting issues
fix:
	@echo "Auto-fixing linting issues..."
	@uv run ruff check --fix app/ tests/
	@echo "✓ Issues fixed"

# Run all quality checks
check: lint
	@echo "Running formatting checks..."
	@uv run ruff format --check app/ tests/
	@echo "✓ Formatting passed"
	@echo "Running tests..."
	@uv run pytest -v
	@echo "✓ All tests passed"
	@echo "✓ All quality checks passed!"

# Build production Docker image
build:
	docker build -t api-service:latest .

# Build and run lint stage (quality checks in Docker)
build-lint:
	@echo "Building lint stage..."
	docker build --target=lint -t api-service:lint .
	@echo "✓ Docker lint stage passed!"

# Run application locally
run:
	uv run uvicorn app.main:app --reload

# Run application locally on specific port
run-port:
	uv run uvicorn app.main:app --reload --port ${PORT}

# Clean up cache and build artifacts
clean:
	@echo "Cleaning up..."
	@rm -rf __pycache__ .pytest_cache .ruff_cache htmlcov .coverage
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type f -name "*.pyo" -delete 2>/dev/null || true
	@echo "✓ Cleanup complete"

# Validate everything before commit
validate: format check
	@echo "✓ Ready to commit!"
