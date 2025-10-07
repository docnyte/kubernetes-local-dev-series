# Minikube Local Development Setup

Complete minikube configuration for the three-tier microservices application.

## Overview

Minikube runs a local Kubernetes cluster on macOS, Linux, and Windows, designed for application developers and new Kubernetes users.

### Architecture

```
┌─────────────────────────────────────────────┐
│         Minikube Cluster (Docker)           │
│                                             │
│  ┌──────────────┐      ┌────────────────┐  │
│  │  API Service │─────→│  Data Service  │  │
│  │   (FastAPI)  │      │  (Spring Boot) │  │
│  └──────────────┘      └────────────────┘  │
│         ↑                      ↓            │
│         │              ┌───────────────┐    │
│    NGINX Ingress       │ host.minikube │    │
│     (addon)            │  .internal    │    │
└─────────┼──────────────┴───────────────┴────┘
          │                       ↓
     HTTP Requests       ┌─────────────────┐
   (minikube IP:80)      │   PostgreSQL    │
                         │  (External DB)  │
                         └─────────────────┘
```

### Cluster Configuration

- **Profile Name**: minikube-local-dev
- **Driver**: docker
- **Nodes**: 3 (1 control-plane + 2 workers)
- **CPUs**: 4 per node
- **Memory**: 4096MB per node
- **Ingress**: NGINX (addon)
- **Namespace**: dev

## Prerequisites

1. **minikube** installed
   ```bash
   # macOS
   brew install minikube

   # Linux
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube

   # Windows (PowerShell as Administrator)
   choco install minikube
   ```

2. **kubectl** installed
   ```bash
   # macOS
   brew install kubectl

   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install kubectl /usr/local/bin/
   ```

3. **Docker** running
   ```bash
   docker ps
   ```

4. **PostgreSQL** container (accessible on host)
   ```bash
   cd ../external/postgres
   docker-compose up -d
   ```

   **IMPORTANT**: PostgreSQL must listen on `0.0.0.0` (all interfaces), not just `127.0.0.1`

## Quick Start

### 1. Create Cluster and Deploy

```bash
cd minikube-setup
./setup.sh
```

This script:
- ✓ Checks prerequisites
- ✓ Creates 3-node minikube cluster
- ✓ Enables ingress and metrics-server addons
- ✓ Builds Docker images
- ✓ Loads images to minikube
- ✓ Deploys all resources
- ✓ Waits for deployments

### 2. Verify Deployment

```bash
kubectl get pods -n dev
kubectl get svc -n dev
kubectl get ingress -n dev
```

### 3. Test Application

```bash
./test.sh
```

Or manually:
```bash
MINIKUBE_IP=$(minikube ip -p minikube-local-dev)
curl http://$MINIKUBE_IP/api/health
curl http://$MINIKUBE_IP/api/users
```

### 4. Clean Up

```bash
minikube delete --profile=minikube-local-dev
```

## Directory Structure

```
minikube-setup/
├── cluster-config.yaml       # Configuration reference
├── setup.sh                  # Automated setup
├── test.sh                   # Test suite
├── README.md                 # This file
└── manifests/
    ├── namespace.yaml
    ├── configmap.yaml
    ├── secrets.yaml
    ├── data-deployment.yaml
    ├── api-deployment.yaml
    ├── services.yaml
    └── ingress.yaml
```

## Configuration

### cluster-config.yaml

Reference file documenting minikube configuration (CLI-based, not declarative like k3d/kind).

### Manifests

**configmap.yaml**: Uses `host.minikube.internal` for PostgreSQL access

**Other manifests**: Identical to k3d/kind setups (standard Kubernetes resources)

## Manual Setup

### 1. Create Cluster

```bash
minikube start \
  --profile=minikube-local-dev \
  --driver=docker \
  --nodes=3 \
  --cpus=4 \
  --memory=4096 \
  --disk-size=20g \
  --kubernetes-version=stable
```

### 2. Enable Addons

```bash
minikube addons enable ingress -p minikube-local-dev
minikube addons enable metrics-server -p minikube-local-dev
```

### 3. Build & Load Images

```bash
docker build -t api-service:latest ../services/api-service
docker build -t data-service:latest ../services/data-service

minikube image load api-service:latest -p minikube-local-dev
minikube image load data-service:latest -p minikube-local-dev
```

### 4. Deploy Resources

```bash
cd manifests
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
kubectl apply -f data-deployment.yaml
kubectl apply -f api-deployment.yaml
kubectl apply -f services.yaml
kubectl apply -f ingress.yaml
```

## Useful Commands

### Cluster Management

```bash
# Status
minikube status -p minikube-local-dev

# Dashboard
minikube dashboard -p minikube-local-dev

# Get IP
minikube ip -p minikube-local-dev

# SSH into node
minikube ssh -p minikube-local-dev

# Pause/unpause
minikube pause -p minikube-local-dev
minikube unpause -p minikube-local-dev

# Delete
minikube delete -p minikube-local-dev
```

### Accessing Services

```bash
# Get service URL (NodePort)
minikube service api-service -n dev -p minikube-local-dev --url

# Tunnel (LoadBalancer support, requires sudo)
minikube tunnel -p minikube-local-dev
```

### Addons

```bash
# List addons
minikube addons list -p minikube-local-dev

# Enable addon
minikube addons enable <addon> -p minikube-local-dev

# Disable addon
minikube addons disable <addon> -p minikube-local-dev
```

### Monitoring

```bash
# Logs
minikube logs -p minikube-local-dev

# Events
kubectl get events -n dev --sort-by='.lastTimestamp'

# Resource usage
kubectl top nodes
kubectl top pods -n dev
```

## Troubleshooting

### PostgreSQL Connection Issues

**Problem**: Data service cannot connect to PostgreSQL

**Solution**:
```bash
# Check PostgreSQL is listening on all interfaces
docker exec postgres-devdb psql -U postgres -t -c "SHOW listen_addresses;"

# Should return '*' or '0.0.0.0', not 'localhost' or '127.0.0.1'

# Test resolution from pod
POD=$(kubectl get pods -n dev -l app=data-service -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -n dev -- getent hosts host.minikube.internal
```

### Ingress Not Working

**Check addon is enabled**:
```bash
minikube addons list -p minikube-local-dev | grep ingress
```

**Check ingress controller**:
```bash
kubectl get pods -n ingress-nginx
```

**Access via minikube IP**:
```bash
MINIKUBE_IP=$(minikube ip -p minikube-local-dev)
curl http://$MINIKUBE_IP/api/health
```

### Image Pull Errors

**Images must be loaded into minikube**:
```bash
minikube image ls -p minikube-local-dev | grep service

# If missing, load them
minikube image load api-service:latest -p minikube-local-dev
minikube image load data-service:latest -p minikube-local-dev
```

### Resource Constraints

**Increase resources**:
```bash
minikube delete -p minikube-local-dev
minikube start -p minikube-local-dev --cpus=6 --memory=8192
```

**Or reduce replicas**:
Edit deployments to use `replicas: 1`

## Minikube vs k3d vs kind

### Minikube Advantages
✓ Most mature local Kubernetes tool
✓ Easy addon system
✓ Built-in dashboard
✓ Multiple driver options (docker, virtualbox, hyperkit, etc.)
✓ Excellent documentation

### Minikube Considerations
- CLI-based configuration (no declarative config file)
- Slower startup than k3d (~2 minutes)
- Images must be manually loaded
- Different networking model (minikube IP vs localhost)

## Additional Resources

- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Minikube Handbook](https://minikube.sigs.k8s.io/docs/handbook/)
- [Minikube Addons](https://minikube.sigs.k8s.io/docs/handbook/addons/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## Next Steps

- [Compare All Three Tools](../docs/comparison.md)
- [Configure k3d Setup](../k3d-setup/README.md)
- [Configure kind Setup](../kind-setup/README.md)
