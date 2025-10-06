# Kubernetes Local Development Series

A comprehensive guide to local Kubernetes development using k3d, Minikube, and kind.

## Overview

This project demonstrates how to set up and manage local Kubernetes clusters with three popular tools:
- **k3d** - Lightweight Kubernetes in Docker (Rancher)
- **Minikube** - Official Kubernetes local development tool
- **kind** - Kubernetes IN Docker (official K8s project)

Each setup includes a complete three-tier microservices architecture showcasing:
- API Service (Python FastAPI)
- Data Service (Java Spring Boot)
- PostgreSQL (External Docker container)

## Architecture

```
External Request (curl)
    ↓
Ingress Controller (NGINX/Traefik)
    ↓
API Service (Python FastAPI) - REST API layer
    ↓
Data Service (Java Spring Boot) - Business logic layer
    ↓
PostgreSQL (Docker Container) - Database outside K8s cluster
```

## Quick Start

### Prerequisites

- Docker installed and running
- kubectl installed
- Python 3.11+ (for local development)
- Java 21+ and Maven (for local development)
- One of: k3d, Minikube, or kind installed

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd kubernetes-local-dev-series
   ```

2. **Start the external database**
   ```bash
   cd external/postgres
   docker-compose up -d
   ```

3. **Choose your Kubernetes tool and run setup**
   ```bash
   # For k3d
   cd k3d-setup && ./setup.sh

   # For Minikube
   cd minikube-setup && ./setup.sh

   # For kind
   cd kind-setup && ./setup.sh
   ```

## Project Structure

```
kubernetes-local-dev-series/
├── services/                  # Shared microservices
│   ├── api-service/          # Python FastAPI service
│   └── data-service/         # Java Spring Boot service
├── external/                  # External Docker resources
│   └── postgres/             # PostgreSQL database
├── k3d-setup/                # k3d-specific setup
├── minikube-setup/           # Minikube-specific setup
├── kind-setup/               # kind-specific setup
├── scripts/                  # Utility scripts
└── docs/                     # Blog post series
```

## Blog Post Series

This repository accompanies a blog series on local Kubernetes development:

1. [Series Introduction](docs/00-series-introduction.md)
2. [Local Kubernetes with k3d](docs/01-k3d-setup.md)
3. [Local Kubernetes with Minikube](docs/02-minikube-setup.md)
4. [Local Kubernetes with kind](docs/03-kind-setup.md)
5. [Comparison and Best Practices](docs/04-comparison.md)

## API Endpoints

### Public API (via Ingress)
- `GET /api/health` - Health check
- `GET /api/users` - List all users
- `GET /api/users/{id}` - Get user by ID

### Internal Data Service
- `GET /data/users` - Fetch from PostgreSQL
- `GET /data/health` - Internal health check

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development instructions.

## License

[TODO: Specify License]

## Contributing

Contributions are welcome! Please follow the code style guidelines in [CLAUDE.md](CLAUDE.md).
