# k3d Local Development Setup

This directory contains the complete k3d configuration for running the three-tier microservices application locally.

## Overview

k3d is a lightweight wrapper to run k3s (Rancher Lab's minimal Kubernetes distribution) in Docker. It's fast, lightweight, and perfect for local development.

### Architecture

```
┌─────────────────────────────────────────────┐
│          k3d Cluster (Docker)               │
│                                             │
│  ┌──────────────┐      ┌────────────────┐  │
│  │  API Service │─────→│  Data Service  │  │
│  │   (FastAPI)  │      │  (Spring Boot) │  │
│  └──────────────┘      └────────────────┘  │
│         ↑                      ↓            │
│         │              ┌───────────────┐    │
│    Traefik Ingress     │ host.k3d      │    │
│         │              │  .internal    │    │
└─────────┼──────────────┴───────────────┴────┘
          │                       ↓
          │              ┌─────────────────┐
     HTTP Requests       │   PostgreSQL    │
     (localhost:80)      │  (External DB)  │
                         └─────────────────┘
```

### Cluster Configuration

- **Cluster Name**: k3d-local-dev
- **Kubernetes Version**: Latest k3s
- **Nodes**: 1 server + 2 agents (workers)
- **Ingress Controller**: Traefik (built-in)
- **Namespace**: dev
- **Network**: k8s-network (shared with PostgreSQL)

## Prerequisites

Before starting, ensure you have:

1. **k3d** installed
   ```bash
   # macOS
   brew install k3d

   # Linux
   curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
   ```

2. **kubectl** installed
   ```bash
   # macOS
   brew install kubectl

   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   ```

3. **Docker** running
   ```bash
   docker --version
   docker ps
   ```

4. **PostgreSQL** container running (in k8s-network)
   ```bash
   cd ../external/postgres
   docker-compose up -d
   ```

## Quick Start

### 1. Create Cluster and Deploy Application

Run the automated setup script:

```bash
cd k3d-setup
./setup.sh
```

This script will:
- ✓ Check prerequisites
- ✓ Create k8s-network if needed
- ✓ Start PostgreSQL if not running
- ✓ Create k3d cluster with 1 server + 2 worker nodes
- ✓ Build Docker images
- ✓ Import images to k3d
- ✓ Deploy all Kubernetes resources
- ✓ Wait for deployments to be ready

### 2. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n dev

# Check services
kubectl get svc -n dev

# Check ingress
kubectl get ingress -n dev
```

### 3. Test the Application

Run the automated test suite:

```bash
./test.sh
```

Or test manually:

```bash
# Health check
curl http://localhost/api/health

# Get users
curl http://localhost/api/users

# Get specific user
curl http://localhost/api/users/1
```

### 4. Clean Up

```bash
# Delete the cluster
k3d cluster delete k3d-local-dev

# Stop PostgreSQL
cd ../external/postgres
docker-compose down
```

## Directory Structure

```
k3d-setup/
├── cluster-config.yaml       # k3d cluster configuration
├── setup.sh                  # Automated setup script
├── test.sh                   # Automated testing script
├── README.md                 # This file
└── manifests/
    ├── namespace.yaml        # Namespace definition
    ├── configmap.yaml        # Application configuration
    ├── secrets.yaml          # Database credentials
    ├── data-deployment.yaml  # Data service deployment
    ├── api-deployment.yaml   # API service deployment
    ├── services.yaml         # Kubernetes services
    └── ingress.yaml          # Traefik ingress configuration
```

## Configuration Files

### cluster-config.yaml

The main k3d configuration file defines:
- Cluster topology (1 server + 2 agents)
- API port exposure (6550)
- Port mappings (80:80, 443:443)
- Network connection (k8s-network)
- Traefik ingress controller settings

### Kubernetes Manifests

**namespace.yaml**: Creates the `dev` namespace

**configmap.yaml**: Non-sensitive configuration
- API service URL
- Log levels
- Database host (host.k3d.internal)
- Java options

**secrets.yaml**: Sensitive credentials
- Database username (base64 encoded)
- Database password (base64 encoded)

**data-deployment.yaml**: Spring Boot service
- 2 replicas
- Resource limits: 256Mi-512Mi memory, 200m-500m CPU
- Liveness/readiness probes via actuator endpoints
- Connects to external PostgreSQL

**api-deployment.yaml**: FastAPI service
- 2 replicas
- Resource limits: 128Mi-256Mi memory, 100m-300m CPU
- Liveness/readiness probes via /api/health
- Connects to data-service internally

**services.yaml**: ClusterIP services
- api-service: Port 8000
- data-service: Port 8080

**ingress.yaml**: Traefik ingress
- Routes /api/* to api-service
- Accessible via http://localhost/api

## Manual Setup

If you prefer manual control:

### 1. Create Cluster

```bash
cd k3d-setup
k3d cluster create --config cluster-config.yaml
```

### 2. Verify Cluster

```bash
kubectl cluster-info
kubectl get nodes
```

### 3. Build Images

```bash
# API Service
cd ../services/api-service
docker build -t api-service:latest .

# Data Service
cd ../services/data-service
docker build -t data-service:latest .
```

### 4. Import Images

```bash
k3d image import api-service:latest -c k3d-local-dev
k3d image import data-service:latest -c k3d-local-dev
```

### 5. Deploy Resources

```bash
cd ../k3d-setup/manifests

kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
kubectl apply -f data-deployment.yaml
kubectl apply -f api-deployment.yaml
kubectl apply -f services.yaml
kubectl apply -f ingress.yaml
```

### 6. Wait for Pods

```bash
kubectl wait --for=condition=Ready pods --all -n dev --timeout=300s
```

## Useful Commands

### Cluster Management

```bash
# List clusters
k3d cluster list

# Stop cluster (preserves state)
k3d cluster stop k3d-local-dev

# Start stopped cluster
k3d cluster start k3d-local-dev

# Delete cluster
k3d cluster delete k3d-local-dev

# Get kubeconfig
k3d kubeconfig get k3d-local-dev
```

### Monitoring

```bash
# Watch pods
kubectl get pods -n dev -w

# View pod logs
kubectl logs -f deployment/api-service -n dev
kubectl logs -f deployment/data-service -n dev

# Describe pod
kubectl describe pod <pod-name> -n dev

# Get events
kubectl get events -n dev --sort-by='.lastTimestamp'

# Port forward (alternative to ingress)
kubectl port-forward svc/api-service 8000:8000 -n dev
```

### Debugging

```bash
# Execute commands in pod
kubectl exec -it <pod-name> -n dev -- /bin/sh

# Test DNS resolution
kubectl exec -it <data-service-pod> -n dev -- nslookup host.k3d.internal

# Test database connectivity
kubectl exec -it <data-service-pod> -n dev -- nc -zv host.k3d.internal 5432

# Check service endpoints
kubectl get endpoints -n dev
```

### Image Management

```bash
# List images in cluster
docker exec k3d-k3d-local-dev-server-0 crictl images

# Import new image version
docker build -t api-service:v2 ../services/api-service
k3d image import api-service:v2 -c k3d-local-dev
```

## Troubleshooting

### Cluster won't start

**Check Docker is running:**
```bash
docker ps
```

**Check network exists:**
```bash
docker network inspect k8s-network
```

**Delete and recreate:**
```bash
k3d cluster delete k3d-local-dev
./setup.sh
```

### Pods stuck in ImagePullBackOff

**Issue**: Images not imported to k3d

**Solution**:
```bash
# Verify images exist locally
docker images | grep service

# Import images
k3d image import api-service:latest -c k3d-local-dev
k3d image import data-service:latest -c k3d-local-dev

# Restart deployments
kubectl rollout restart deployment/api-service -n dev
kubectl rollout restart deployment/data-service -n dev
```

### Pods stuck in CrashLoopBackOff

**Check logs:**
```bash
kubectl logs <pod-name> -n dev
kubectl describe pod <pod-name> -n dev
```

**Common issues:**
- Database not accessible (check host.k3d.internal resolution)
- Configuration errors (check configmap/secrets)
- Resource limits too low (increase in deployment yaml)

### Data service can't connect to PostgreSQL

**Check PostgreSQL is running:**
```bash
docker ps | grep postgres-devdb
```

**Test connectivity from host:**
```bash
psql -h localhost -p 5432 -U postgres -d devdb
```

**Check k3d can resolve host:**
```bash
kubectl exec -it <data-service-pod> -n dev -- nslookup host.k3d.internal
```

**Verify environment variables:**
```bash
kubectl exec <data-service-pod> -n dev -- env | grep DB_
```

### Ingress not working

**Check Traefik is running:**
```bash
kubectl get pods -n kube-system | grep traefik
```

**Check ingress status:**
```bash
kubectl describe ingress api-ingress -n dev
```

**Test without ingress (port-forward):**
```bash
kubectl port-forward svc/api-service 8000:8000 -n dev
curl http://localhost:8000/api/health
```

### Port 80 already in use

**Find process using port 80:**
```bash
lsof -i :80
```

**Use different port:**
Edit `cluster-config.yaml`:
```yaml
ports:
  - port: 8080:80
    nodeFilters:
      - loadbalancer
```

Then access via http://localhost:8080/api

## k3d vs Minikube vs kind

### k3d Advantages
✓ Fastest startup time (~30s)
✓ Lowest resource usage
✓ Built-in Traefik ingress
✓ Easy multi-node clusters
✓ Native Docker integration

### k3d Considerations
- Different from production k8s (k3s is minimal)
- Limited to Docker driver
- Some k8s features removed in k3s

## Performance Tuning

### Reduce Resource Usage

Edit deployments to use fewer resources:
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

### Reduce Replica Count

For resource-constrained environments:
```yaml
spec:
  replicas: 1
```

### Disable Metrics

Already configured in cluster-config.yaml:
```yaml
- arg: --disable=metrics-server
  nodeFilters:
    - server:*
```

## Additional Resources

- [k3d Documentation](https://k3d.io/)
- [k3s Documentation](https://docs.k3s.io/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## Next Steps

- [Configure Minikube Setup](../minikube-setup/README.md)
- [Configure kind Setup](../kind-setup/README.md)
- [Compare All Three Tools](../docs/comparison.md)
