# Multi-stage Dockerfile for Python FastAPI service using uv

# =============================================================================
# Lint Stage (Optional - for CI/CD quality checks)
# Build with: docker build --target=lint -t api-service:lint .
# =============================================================================
FROM python:3.13-slim AS lint

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Set working directory
WORKDIR /app

# Copy dependency files
COPY pyproject.toml ./

# Install all dependencies including dev dependencies (ruff, pytest, etc.)
RUN uv venv /opt/venv && \
    . /opt/venv/bin/activate && \
    uv pip install -r pyproject.toml --all-extras

# Set PATH to use virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# Copy source code and tests
COPY app/ ./app/
COPY tests/ ./tests/

# Run linting and formatting checks
RUN echo "Running ruff linting checks..." && \
    ruff check app/ tests/ && \
    echo "✓ Linting passed" && \
    echo "Running ruff formatting checks..." && \
    ruff format --check app/ tests/ && \
    echo "✓ Formatting passed" && \
    echo "Running pytest..." && \
    pytest -v && \
    echo "✓ All tests passed" && \
    echo "✓ Quality checks complete!"

# =============================================================================
# Builder Stage (Dependencies only)
# =============================================================================
FROM python:3.13-slim AS builder

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Set working directory
WORKDIR /app

# Copy dependency files
COPY pyproject.toml ./

# Install production dependencies only into a virtual environment
RUN uv venv /opt/venv && \
    . /opt/venv/bin/activate && \
    uv pip install -r pyproject.toml

# =============================================================================
# Production Stage (Final minimal image)
# =============================================================================
FROM python:3.13-slim

# Set working directory
WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Copy application code (no tests, no dev files)
COPY app/ ./app/

# Set environment variables
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

# Expose application port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/health')"

# Run the application
# --no-access-log disables uvicorn's access logging to reduce noise from K8s health checks
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
