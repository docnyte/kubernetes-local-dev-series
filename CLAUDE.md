# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Educational blog series with hands-on examples demonstrating local Kubernetes development using k3d, Minikube, and kind. The project implements a three-tier microservices architecture (Python FastAPI → Java Spring Boot → PostgreSQL) replicated across all three Kubernetes tools to compare their features and workflows.

## Architecture

Three-tier architecture with cross-network communication:
- **API Service** (Python/FastAPI): Public REST API exposed via Ingress
- **Data Service** (Java/Spring Boot): Internal ClusterIP service
- **PostgreSQL**: External Docker container (NOT in K8s) to demonstrate K8s-to-Docker networking

Key architectural point: PostgreSQL runs outside Kubernetes to showcase networking between K8s clusters and external Docker containers using `host.docker.internal` or tool-specific DNS.

## Repository Structure

```
kubernetes-local-dev-series/
├── services/
│   ├── api-service/          # Python FastAPI (port 8000)
│   └── data-service/         # Java Spring Boot (port 8080)
├── external/
│   └── postgres/             # Standalone Docker container
├── k3d-setup/
│   ├── manifests/            # K8s YAML files
│   └── setup.sh              # Cluster creation + deployment
├── minikube-setup/
│   ├── manifests/
│   └── setup.sh
├── kind-setup/
│   ├── manifests/
│   └── setup.sh
├── scripts/                  # Cross-tool utilities
└── docs/                     # Blog post drafts
```

## Development Commands

### Python Setup (using uv)
```bash
# Install dependencies
cd services/api-service
uv sync

# Run locally
uv run uvicorn app.main:app --reload

# Run tests
uv run pytest
```

### Build Docker Images
```bash
# API Service (Python)
cd services/api-service
docker build -t api-service:latest .

# Data Service (Java)
cd services/data-service
docker build -t data-service:latest .
```

### Start External Database
```bash
cd external/postgres
docker-compose up -d
```

### Deploy to Kubernetes
```bash
# k3d example
cd k3d-setup
./setup.sh

# Minikube example
cd minikube-setup
./setup.sh

# kind example
cd kind-setup
./setup.sh
```

### Testing
```bash
# Test specific setup
cd <tool>-setup
./test.sh

# Test all setups
./scripts/test-all.sh
```

### Cleanup
```bash
./scripts/cleanup.sh
```

## Service Communication Flow

```
curl → Ingress → API Service (FastAPI) → Data Service (Spring Boot) → PostgreSQL (Docker)
```

- API → Data: `http://data-service:8080` (Kubernetes DNS)
- Data → PostgreSQL: `host.docker.internal:5432` (or tool-specific host)

## Environment Variables

### API Service
- `DATA_SERVICE_URL`: `http://data-service:8080`
- `PORT`: `8000`
- `LOG_LEVEL`: `INFO`

### Data Service
- `SPRING_DATASOURCE_URL`: JDBC URL to external PostgreSQL
- `SPRING_DATASOURCE_USERNAME`: `postgres`
- `SPRING_DATASOURCE_PASSWORD`: `postgres`
- `SERVER_PORT`: `8080`

### PostgreSQL
- `POSTGRES_USER`: `postgres`
- `POSTGRES_PASSWORD`: `postgres`
- `POSTGRES_DB`: `devdb`
- **No persistent volumes**: Data is ephemeral for dev/testing (intentional design choice)

## API Endpoints

### Public API (via Ingress)
- `GET /api/health` - Health check
- `GET /api/users` - List all users
- `GET /api/users/{id}` - Get user by ID

### Internal Data Service (ClusterIP only)
- `GET /data/users` - Fetch from PostgreSQL
- `GET /data/health` - Internal health check

## Tool-Specific Differences

### Ingress Controllers
- **k3d**: Traefik (built-in)
- **Minikube**: NGINX (addon: `minikube addons enable ingress`)
- **kind**: NGINX (manual installation required)

### PostgreSQL Host Resolution
- **k3d**: `host.docker.internal` or `host.k3d.internal`
- **Minikube**: Requires `--network=host` or specific IP
- **kind**: `host.docker.internal` with extra configuration

## Code Style Guidelines

### Python (API Service)
- Use **uv** for dependency management (not pip/poetry)
- PEP 8 style
- Type hints required
- Async/await for I/O
- pytest for tests
- Docstrings for all functions

### Java (Data Service)
- Google Java Style Guide
- Spring Boot best practices
- Dependency injection
- JUnit 5 for tests
- Javadoc for public classes

### Kubernetes Manifests
- Always include resource limits/requests
- Add liveness/readiness probes
- Use ConfigMaps for config, Secrets for credentials
- Consistent labels: `app`, `component`, `tier`

## Critical Design Principles

1. **Shared Services**: The same services/ directory code is used across all three K8s tools. Never create tool-specific service code.

2. **Consistency**: When modifying manifests for one tool, apply similar changes to other tool setups unless there's a tool-specific reason not to.

3. **External Database**: PostgreSQL MUST remain outside Kubernetes to demonstrate cross-network communication patterns. The database uses no persistent volumes - data is ephemeral and resets on container removal, providing a clean state for each test run.

4. **Educational Focus**: Code should be readable and well-commented for blog readers learning Kubernetes.

## Network Debugging

If services can't communicate:
1. Check service/pod status: `kubectl get pods,svc`
2. Test DNS: `kubectl exec -it <api-pod> -- nslookup data-service`
3. Check logs: `kubectl logs <pod-name>`
4. Verify PostgreSQL: `docker ps | grep postgres`
5. Test DB connection from host: `psql -h localhost -p 5432 -U postgres -d devdb`
