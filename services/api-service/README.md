# API Service (Python FastAPI)

Python FastAPI service that provides the public REST API for the Kubernetes local development tutorial. This service acts as the gateway to the data service and handles all external HTTP requests.

## Features

- **FastAPI Framework**: Modern, fast Python web framework with automatic API documentation
- **Type Safety**: Full type hints and Pydantic models for request/response validation
- **Async/Await**: Asynchronous request handling for better performance
- **Health Checks**: Built-in health check endpoint with data service connectivity status
- **Auto Documentation**: Interactive API docs at `/docs` (Swagger UI) and `/redoc` (ReDoc)
- **Configuration Management**: Environment-based configuration using pydantic-settings
- **Comprehensive Tests**: Unit tests with mocking for all endpoints
- **Docker Ready**: Multi-stage Dockerfile optimized for production

## Architecture

```
External Requests → API Service (FastAPI) → Data Service (Spring Boot) → PostgreSQL
```

The API Service:
- Exposes public endpoints via Kubernetes Ingress
- Proxies user requests to the internal Data Service
- Handles error responses and service unavailability
- Provides health check for monitoring

## API Endpoints

### Public API (via Ingress)

- `GET /api/health` - Health check with data service status
- `GET /api/users` - List all users
- `GET /api/users/{id}` - Get user by ID
- `GET /docs` - Interactive API documentation (Swagger UI)
- `GET /openapi.json` - OpenAPI schema

## Technology Stack

- **Python**: 3.13+
- **Framework**: FastAPI 0.115+
- **HTTP Client**: httpx 0.27+ (async)
- **Config**: pydantic-settings 2.6+
- **Server**: uvicorn 0.32+ with uvloop
- **Package Manager**: uv (modern Python package installer)
- **Testing**: pytest 8.3+ with pytest-asyncio
- **Linting/Formatting**: ruff 0.9+ (extremely fast Python linter and formatter)

## Development Setup

### Prerequisites

- Python 3.13+
- [uv](https://github.com/astral-sh/uv) package manager
- make (optional, for convenient commands)
- Docker (optional, for containerized builds)

### Quick Start with Make

The project includes a Makefile for common development tasks:

```bash
# View all available commands
make help

# Install dependencies and run checks
make dev        # Install all dependencies
make check      # Run linting, formatting, and tests
make run        # Run the application locally
```

### Install Dependencies

```bash
# Using make (recommended)
make dev

# Or using uv directly
uv sync --all-extras

# Install only production dependencies
uv sync
```

### Run Locally

```bash
# Using make (recommended)
make run

# Or using uv directly
uv run uvicorn app.main:app --reload

# Or activate virtual environment
source .venv/bin/activate
uvicorn app.main:app --reload
```

The API will be available at http://localhost:8000

### Environment Variables

Create a `.env` file or set environment variables:

```env
DATA_SERVICE_URL=http://localhost:8080  # URL to data service
PORT=8000                               # API service port
LOG_LEVEL=INFO                          # Logging level (DEBUG, INFO, WARNING, ERROR)
```

### Run Tests

```bash
# Using make (recommended)
make test           # Run all tests
make test-cov       # Run with coverage report

# Or using uv directly
uv run pytest
uv run pytest --cov=app --cov-report=html
uv run pytest -v
uv run pytest tests/test_health.py
```

### Linting and Formatting

The project uses [Ruff](https://docs.astral.sh/ruff/) for linting and code formatting.

```bash
# Using make (recommended)
make lint           # Check for linting issues
make format         # Format code
make fix            # Auto-fix linting issues
make check          # Run all checks (lint + format + test)
make validate       # Format code + run all checks

# Or using uv/ruff directly
uv run ruff check app/ tests/
uv run ruff check --fix app/ tests/
uv run ruff format app/ tests/
uv run ruff format --check app/ tests/
```

## Docker

The Dockerfile includes a multi-stage build with an optional `lint` stage for quality checks in CI/CD.

### Build Production Image

```bash
# Using make
make build

# Or using docker directly
docker build -t api-service:latest .
```

### Build with Quality Checks (Lint Stage)

The `lint` stage runs ruff checks and tests in a containerized environment:

```bash
# Using make (recommended for CI/CD)
make build-lint

# Or using docker directly
docker build --target=lint -t api-service:lint .
```

**What the lint stage does:**
- ✅ Installs all dependencies (including dev dependencies)
- ✅ Runs `ruff check` for linting
- ✅ Runs `ruff format --check` for formatting
- ✅ Runs `pytest` for tests
- ✅ Fails the build if any check fails

**Best Practice**: Run `make build-lint` in your CI/CD pipeline before building the production image. This ensures code quality without slowing down production builds.

### Run Container

```bash
docker run -p 8000:8000 \
  -e DATA_SERVICE_URL=http://data-service:8080 \
  api-service:latest
```

## Project Structure

```
api-service/
├── app/
│   ├── __init__.py
│   ├── main.py           # FastAPI application entry point
│   ├── config.py         # Configuration management
│   ├── models.py         # Pydantic models
│   └── routers/
│       ├── __init__.py
│       ├── health.py     # Health check endpoints
│       └── users.py      # User endpoints
├── tests/
│   ├── __init__.py
│   ├── test_health.py    # Health endpoint tests
│   └── test_users.py     # User endpoint tests
├── Dockerfile            # Multi-stage Docker build
├── pyproject.toml        # Project dependencies and config
└── README.md            # This file
```

## Code Quality

### Type Checking

All code uses Python type hints:

```python
async def get_user(user_id: int) -> User:
    """Fetch a specific user by ID."""
    ...
```

### Pydantic Models

Request/response validation with Pydantic:

```python
class User(BaseModel):
    id: int
    name: str
    email: str
```

### Async/Await

All I/O operations use async/await:

```python
async with httpx.AsyncClient() as client:
    response = await client.get(url)
```

## Kubernetes Deployment

This service is designed to run in Kubernetes with:

- **Service Type**: ClusterIP (behind Ingress)
- **Ingress**: Exposes `/api/*` paths publicly
- **Health Check**: `/api/health` for liveness/readiness probes
- **Resource Limits**: Configured in K8s manifests
- **Environment**: Config via ConfigMap/Secrets
- **Logging**: Uvicorn access logs disabled (`--no-access-log`) to reduce noise from health check probes

See the `k3d-setup/`, `minikube-setup/`, or `kind-setup/` directories for Kubernetes manifests.

### Logging Configuration

The service uses structured logging with configurable levels:

- **Application logs**: Controlled via `LOG_LEVEL` environment variable (DEBUG, INFO, WARNING, ERROR)
- **Access logs**: Disabled in production to prevent health check spam from Kubernetes probes
- **Health checks**: K8s liveness/readiness probes hit `/api/health` every 5-10 seconds

To enable access logs for debugging (local development):
```bash
uvicorn app.main:app --reload  # Access logs enabled by default
```

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

This ensures code quality without requiring CI runners to have Python/uv installed.

## License

This is an educational project for the Kubernetes local development blog series.
