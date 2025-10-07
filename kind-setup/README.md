# kind Local Development Setup

This directory contains the complete kind configuration for running the three-tier microservices application locally.

## Overview

kind (Kubernetes IN Docker) is a tool for running local Kubernetes clusters using Docker container "nodes". It's primarily designed for testing Kubernetes itself, but also works well for local development and CI pipelines.

### Architecture

```
┌─────────────────────────────────────────────┐
│          kind Cluster (Docker)              │
│                                             │
│  ┌──────────────┐      ┌────────────────┐  │
│  │  API Service │─────→│  Data Service  │  │
│  │   (FastAPI)  │      │  (Spring Boot) │  │
│  └──────────────┘      └────────────────┘  │
│         ↑                      ↓            │
│         │              ┌───────────────┐    │
│    NGINX Ingress       │ host.docker   │    │
│         │              │  .internal    │    │
└─────────┼──────────────┴───────────────┴────┘
          │                       ↓
          │              ┌─────────────────┐
     HTTP Requests       │   PostgreSQL    │
     (localhost:80)      │  (External DB)  │
                         └─────────────────┘
```

### Cluster Configuration

- **Cluster Name**: kind-local-dev
- **Kubernetes Version**: Latest (configurable in cluster-config.yaml)
- **Nodes**: 1 control-plane + 2 workers
- **Ingress Controller**: NGINX (manually installed)
- **Namespace**: dev
- **Network**: Connected to k8s-network (shared with PostgreSQL)

## Prerequisites

Before starting, ensure you have:

1. **kind** installed
   ```bash
   # macOS
   brew install kind

   # Linux
   curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
   chmod +x ./kind
   sudo mv ./kind /usr/local/bin/kind

   # Windows (PowerShell)
   curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
   Move-Item .\kind-windows-amd64.exe c:\some-dir-in-your-PATH\kind.exe
   ```

2. **kubectl** installed
   ```bash
   # macOS
   brew install kubectl

   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl
   sudo mv kubectl /usr/local/bin/
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
cd kind-setup
./setup.sh
```

This script will:
- ✓ Check prerequisites
- ✓ Create k8s-network if needed
- ✓ Start PostgreSQL if not running
- ✓ Create kind cluster with 1 control-plane + 2 worker nodes
- ✓ Connect cluster nodes to k8s-network
- ✓ Install NGINX ingress controller
- ✓ Build Docker images
- ✓ Load images to kind cluster
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

# Check NGINX ingress controller
kubectl get pods -n ingress-nginx
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
kind delete cluster --name kind-local-dev

# Stop PostgreSQL
cd ../external/postgres
docker-compose down
```

## Directory Structure

```
kind-setup/
├── cluster-config.yaml       # kind cluster configuration
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
    └── ingress.yaml          # NGINX ingress configuration
```

## Configuration Files

### cluster-config.yaml

The main kind configuration file defines:
- Cluster topology (1 control-plane + 2 workers)
- Port mappings (80:80, 443:443)
- Node labels for ingress (ingress-ready=true)
- Networking configuration (pod/service subnets)
- Kubeadm config patches

### Kubernetes Manifests

**namespace.yaml**: Creates the `dev` namespace

**configmap.yaml**: Non-sensitive configuration
- API service URL
- Log levels
- Database host (host.docker.internal)
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

**ingress.yaml**: NGINX ingress
- Routes /api/* to api-service
- Accessible via http://localhost/api
- Rewrite rules to strip /api prefix

## Manual Setup

If you prefer manual control:

### 1. Create Cluster

```bash
cd kind-setup
kind create cluster --config cluster-config.yaml
```

### 2. Connect to k8s-network

```bash
# Connect all kind nodes to k8s-network
docker network connect k8s-network kind-local-dev-control-plane
docker network connect k8s-network kind-local-dev-worker
docker network connect k8s-network kind-local-dev-worker2
```

### 3. Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### 4. Build Images

```bash
# API Service
cd ../services/api-service
docker build -t api-service:latest .

# Data Service
cd ../services/data-service
docker build -t data-service:latest .
```

### 5. Load Images to kind

```bash
kind load docker-image api-service:latest --name kind-local-dev
kind load docker-image data-service:latest --name kind-local-dev
```

### 6. Deploy Resources

```bash
cd ../kind-setup/manifests

kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
kubectl apply -f data-deployment.yaml
kubectl apply -f api-deployment.yaml
kubectl apply -f services.yaml
kubectl apply -f ingress.yaml
```

### 7. Wait for Pods

```bash
kubectl wait --for=condition=Ready pods --all -n dev --timeout=300s
```

## Useful Commands

### Cluster Management

```bash
# List clusters
kind get clusters

# Delete cluster
kind delete cluster --name kind-local-dev

# Get kubeconfig
kind get kubeconfig --name kind-local-dev

# Export kubeconfig
kind export kubeconfig --name kind-local-dev
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
kubectl exec -it <data-service-pod> -n dev -- nslookup host.docker.internal

# Test database connectivity
kubectl exec -it <data-service-pod> -n dev -- nc -zv host.docker.internal 5432

# Check service endpoints
kubectl get endpoints -n dev

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Image Management

```bash
# Load new image version
docker build -t api-service:v2 ../services/api-service
kind load docker-image api-service:v2 --name kind-local-dev

# List images in cluster nodes
docker exec kind-local-dev-control-plane crictl images
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
kind delete cluster --name kind-local-dev
./setup.sh
```

### Pods stuck in ImagePullBackOff

**Issue**: Images not loaded to kind

**Solution**:
```bash
# Verify images exist locally
docker images | grep service

# Load images
kind load docker-image api-service:latest --name kind-local-dev
kind load docker-image data-service:latest --name kind-local-dev

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
- Database not accessible (check host.docker.internal resolution)
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

**Check kind nodes are on k8s-network:**
```bash
docker inspect kind-local-dev-control-plane | grep k8s-network
```

**Verify environment variables:**
```bash
kubectl exec <data-service-pod> -n dev -- env | grep DB_
```

**Test host.docker.internal resolution:**
```bash
kubectl exec <data-service-pod> -n dev -- getent hosts host.docker.internal
```

### Ingress not working

**Check NGINX ingress controller is running:**
```bash
kubectl get pods -n ingress-nginx
```

**Check ingress status:**
```bash
kubectl describe ingress api-ingress -n dev
```

**Check ingress controller logs:**
```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
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

**Kill the process or use different port:**
Edit `cluster-config.yaml` and change port mapping:
```yaml
extraPortMappings:
  - containerPort: 80
    hostPort: 8080  # Changed from 80
    protocol: TCP
```

Then access via http://localhost:8080/api

### host.docker.internal not resolving

**Check if nodes are connected to k8s-network:**
```bash
for node in $(docker ps --filter "name=kind-local-dev" --format "{{.Names}}"); do
  echo "Checking $node:"
  docker inspect $node --format '{{range $net, $v := .NetworkSettings.Networks}}{{$net}} {{end}}'
done
```

**Reconnect nodes to network:**
```bash
docker network connect k8s-network kind-local-dev-control-plane
docker network connect k8s-network kind-local-dev-worker
docker network connect k8s-network kind-local-dev-worker2
```

## kind vs k3d vs Minikube

### kind Advantages
✓ Official CNCF project for testing Kubernetes
✓ Multi-node clusters by default
✓ Fast cluster creation (~1 minute)
✓ Reproducible with config files
✓ Excellent CI/CD integration

### kind Considerations
- Requires manual ingress controller installation
- More complex networking setup for external containers
- Images must be manually loaded (not automatic like k3d)
- Slightly higher resource usage than k3d

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

### Use Single Worker Node

Edit `cluster-config.yaml`:
```yaml
nodes:
  - role: control-plane
    # ... port mappings ...
  - role: worker
  # Remove second worker
```

## Additional Resources

- [kind Documentation](https://kind.sigs.k8s.io/)
- [kind Configuration Reference](https://kind.sigs.k8s.io/docs/user/configuration/)
- [NGINX Ingress for kind](https://kind.sigs.k8s.io/docs/user/ingress/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## Next Steps

- [Configure Minikube Setup](../minikube-setup/README.md)
- [Compare All Three Tools](../docs/comparison.md)
- Learn about [Advanced kind Features](https://kind.sigs.k8s.io/docs/user/quick-start/)
