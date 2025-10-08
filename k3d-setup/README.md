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
- **Local Registry**: registry.localhost:5000
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

## Directory Structure

```
k3d-setup/
├── cluster-config.yaml       # k3d cluster configuration
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

## Setup Steps

Follow these steps to set up your k3d cluster and deploy the three-tier application.

### 1. Verify Prerequisites

Check that all required tools are installed:

```bash
# Check k3d installation
k3d version

# Check kubectl installation
kubectl version --client

# Check Docker is running
docker ps
```

### 2. Create Docker Network

Create a shared Docker network for k3d cluster and PostgreSQL container:

```bash
# Create network (if it doesn't exist)
docker network create k8s-network

# Verify network exists
docker network inspect k8s-network
```

### 3. Start PostgreSQL Database

Start the external PostgreSQL container that will be accessed by the data-service:

```bash
# Navigate to postgres directory
cd ../external/postgres

# Start PostgreSQL with docker-compose
docker-compose up -d

# Verify PostgreSQL is running
docker ps | grep postgres-devdb

# Wait a few seconds for PostgreSQL to initialize
sleep 5

# Return to k3d-setup directory
cd ../../k3d-setup
```

**Note**: PostgreSQL runs outside Kubernetes to demonstrate cross-network communication patterns.

### 4. Create k3d Cluster

Create the k3d cluster using the configuration file:

```bash
# Create cluster with configuration
k3d cluster create --config cluster-config.yaml

# This creates:
# - 1 server node (control plane)
# - 2 agent nodes (workers)
# - Local Docker registry at localhost:5000
# - Traefik ingress controller
# - Connection to k8s-network
```

Wait for the cluster to be ready:

```bash
# Wait for all nodes to be ready (max 2 minutes)
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Verify cluster info
kubectl cluster-info

# Check all nodes are ready
kubectl get nodes
```

You should see 3 nodes: 1 server and 2 agents, all in "Ready" status.

### 5. Build Docker Images

Build the microservice Docker images:

```bash
# Build API service (Python/FastAPI)
docker build -t api-service:latest ../services/api-service

# Verify api-service image was created
docker images | grep api-service

# Build data service (Java/Spring Boot)
docker build -t data-service:latest ../services/data-service

# Verify data-service image was created
docker images | grep data-service
```

### 6. Push Images to Local Registry

The k3d cluster includes a local Docker registry. Push your images to it:

```bash
# Wait for registry to be ready
# The registry should respond with {} when ready
until curl -s http://localhost:5000/v2/ > /dev/null 2>&1; do
  echo "Waiting for registry..."
  sleep 2
done
echo "Registry is ready!"

# Tag api-service for local registry
docker tag api-service:latest localhost:5000/api-service:latest

# Push api-service to registry
docker push localhost:5000/api-service:latest

# Tag data-service for local registry
docker tag data-service:latest localhost:5000/data-service:latest

# Push data-service to registry
docker push localhost:5000/data-service:latest

# Verify images are in registry
curl http://localhost:5000/v2/_catalog
# Should show: {"repositories":["api-service","data-service"]}
```

### 7. Deploy Kubernetes Resources

Deploy all application components to the cluster in the correct order:

```bash
# Navigate to manifests directory
cd manifests

# 1. Create namespace
kubectl apply -f namespace.yaml

# 2. Create ConfigMap (non-sensitive configuration)
kubectl apply -f configmap.yaml

# 3. Create Secrets (database credentials)
kubectl apply -f secrets.yaml

# 4. Deploy data-service (Spring Boot)
kubectl apply -f data-deployment.yaml

# 5. Deploy api-service (FastAPI)
kubectl apply -f api-deployment.yaml

# 6. Create Kubernetes Services
kubectl apply -f services.yaml

# 7. Create Ingress for external access
kubectl apply -f ingress.yaml

# Return to k3d-setup directory
cd ..
```

### 8. Wait for Deployments to be Ready

Monitor the deployment rollout:

```bash
# Watch all pods in the dev namespace
kubectl get pods -n dev -w

# Or wait for data-service deployment to complete (max 5 minutes)
kubectl rollout status deployment/data-service -n dev --timeout=300s

# Wait for api-service deployment to complete (max 5 minutes)
kubectl rollout status deployment/api-service -n dev --timeout=300s
```

### 9. Verify Deployment

Check that all components are running:

```bash
# Check all pods are running
kubectl get pods -n dev

# Check services are created
kubectl get svc -n dev

# Check ingress is configured
kubectl get ingress -n dev

# View more details
kubectl get all -n dev
```

You should see:
- 2 api-service pods running
- 2 data-service pods running
- 2 services (api-service and data-service)
- 1 ingress (api-ingress)

### 10. Test the Application

Test the API endpoints:

```bash
# Health check
curl http://localhost/api/health

# Get all users
curl http://localhost/api/users

# Get specific user
curl http://localhost/api/users/1
```

**Success!** You now have a fully functional three-tier application running on k3d.

## Testing the Deployment

Run these validation checks to ensure everything is working correctly.

### Test 1: Cluster and Namespace

```bash
# Verify cluster exists
k3d cluster list | grep k3d-local-dev

# Verify namespace exists
kubectl get namespace dev
```

### Test 2: Pod Health

```bash
# Check all pods are running
kubectl get pods -n dev

# Check no pods are failing
kubectl get pods -n dev --field-selector=status.phase!=Running

# Check deployment readiness
kubectl get deployments -n dev

# Expected output: All pods in "Running" state, deployments with READY 2/2
```

### Test 3: Pod Readiness Probes

```bash
# Check data-service replicas
kubectl get deployment data-service -n dev -o jsonpath='{.status.readyReplicas}/{.spec.replicas}'
# Expected: 2/2

# Check api-service replicas
kubectl get deployment api-service -n dev -o jsonpath='{.status.readyReplicas}/{.spec.replicas}'
# Expected: 2/2
```

### Test 4: Services

```bash
# Verify api-service exists
kubectl get service api-service -n dev

# Verify data-service exists
kubectl get service data-service -n dev

# Check service endpoints are populated
kubectl get endpoints -n dev
```

### Test 5: Ingress

```bash
# Verify ingress exists
kubectl get ingress api-ingress -n dev

# Describe ingress for details
kubectl describe ingress api-ingress -n dev
```

### Test 6: Local Registry

```bash
# Check registry container is running
docker ps | grep registry.localhost

# Test registry API
curl http://localhost:5000/v2/
# Expected: {}

# List images in registry
curl http://localhost:5000/v2/_catalog
# Expected: {"repositories":["api-service","data-service"]}

# Check api-service tags
curl http://localhost:5000/v2/api-service/tags/list

# Check data-service tags
curl http://localhost:5000/v2/data-service/tags/list
```

### Test 7: PostgreSQL Connectivity

```bash
# Verify PostgreSQL container is running
docker ps | grep postgres-devdb

# Get a data-service pod name
DATA_POD=$(kubectl get pods -n dev -l app=data-service -o jsonpath='{.items[0].metadata.name}')

# Check data-service logs for database errors
kubectl logs $DATA_POD -n dev | grep -i "error.*database\|connection.*refused\|connection.*timeout"
# Expected: No output (no errors)

# Test DNS resolution from within the cluster
kubectl exec -it $DATA_POD -n dev -- nslookup host.k3d.internal

# Test database connectivity
kubectl exec -it $DATA_POD -n dev -- nc -zv host.k3d.internal 5432
```

### Test 8: API Endpoints

```bash
# Test health endpoint
curl -i http://localhost/api/health
# Expected: HTTP/1.1 200 OK

# Test users endpoint
curl -i http://localhost/api/users
# Expected: HTTP/1.1 200 OK with JSON response

# View response data
curl http://localhost/api/users | head -n 20

# Test specific user endpoint
curl http://localhost/api/users/1
```

### Test 9: Full Request Flow

This tests the complete flow: Ingress → API Service → Data Service → PostgreSQL

```bash
# Get a user (full flow test)
curl -v http://localhost/api/users/1

# Check api-service logs
kubectl logs -l app=api-service -n dev --tail=20

# Check data-service logs
kubectl logs -l app=data-service -n dev --tail=20
```

## Local Docker Registry

k3d is configured with a local Docker registry that provides a realistic development workflow similar to production environments.

### Registry Configuration

- **Registry Name**: registry.localhost
- **Host Port**: 5000
- **Cluster Access**: k3d-registry.localhost:5000
- **Host Access**: localhost:5000

### Registry Usage

**List images in registry:**
```bash
curl http://localhost:5000/v2/_catalog
```

**List tags for an image:**
```bash
curl http://localhost:5000/v2/api-service/tags/list
```

**Push a new image:**
```bash
docker tag my-app:latest localhost:5000/my-app:latest
docker push localhost:5000/my-app:latest
```

**Update deployment to use new image:**
```bash
kubectl set image deployment/my-app my-app=registry.localhost:5000/my-app:latest -n dev
```

### Benefits of Local Registry

✓ **Realistic workflow**: Mimics production registry pattern
✓ **Faster updates**: No need to import images for each change
✓ **Image versioning**: Support for multiple tags
✓ **Cluster isolation**: Images available only to your cluster
✓ **CI/CD testing**: Test registry-based workflows locally

## Configuration Files

### cluster-config.yaml

The main k3d configuration file defines:
- Cluster topology (1 server + 2 agents)
- API port exposure (6550)
- Port mappings (80:80, 443:443)
- Network connection (k8s-network)
- Local Docker registry (registry.localhost:5000)
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

## Useful Commands

### Cluster Management

```bash
# List all clusters
k3d cluster list

# Stop cluster (preserves state)
k3d cluster stop k3d-local-dev

# Start stopped cluster
k3d cluster start k3d-local-dev

# Delete cluster completely
k3d cluster delete k3d-local-dev

# Get kubeconfig for cluster
k3d kubeconfig get k3d-local-dev
```

### Monitoring

```bash
# Watch pods in real-time
kubectl get pods -n dev -w

# View api-service logs (follow mode)
kubectl logs -f deployment/api-service -n dev

# View data-service logs (follow mode)
kubectl logs -f deployment/data-service -n dev

# View logs from all api-service pods
kubectl logs -l app=api-service -n dev

# Describe a specific pod
kubectl describe pod <pod-name> -n dev

# Get recent events sorted by timestamp
kubectl get events -n dev --sort-by='.lastTimestamp'

# Port forward service (alternative to ingress)
kubectl port-forward svc/api-service 8000:8000 -n dev
```

### Debugging

```bash
# Execute shell in a pod
kubectl exec -it <pod-name> -n dev -- /bin/sh

# Test DNS resolution from within cluster
kubectl exec -it <pod-name> -n dev -- nslookup data-service
kubectl exec -it <pod-name> -n dev -- nslookup host.k3d.internal

# Test database connectivity from data-service pod
kubectl exec -it <data-service-pod> -n dev -- nc -zv host.k3d.internal 5432

# Check service endpoints
kubectl get endpoints -n dev

# View configmap contents
kubectl get configmap app-config -n dev -o yaml

# View secrets (base64 encoded)
kubectl get secret db-secrets -n dev -o yaml
```

### Image Management

```bash
# List images in registry
curl http://localhost:5000/v2/_catalog

# List tags for api-service
curl http://localhost:5000/v2/api-service/tags/list

# Build and push new image version
docker build -t api-service:v2 ../services/api-service
docker tag api-service:v2 localhost:5000/api-service:v2
docker push localhost:5000/api-service:v2

# Update deployment to use new version
kubectl set image deployment/api-service api-service=registry.localhost:5000/api-service:v2 -n dev

# Or restart deployment to pull latest tag
kubectl rollout restart deployment/api-service -n dev

# Check rollout status
kubectl rollout status deployment/api-service -n dev

# View rollout history
kubectl rollout history deployment/api-service -n dev
```

## Cleanup

When you're done, clean up all resources:

```bash
# Delete the k3d cluster (removes cluster, registry, and all resources)
k3d cluster delete k3d-local-dev

# Stop PostgreSQL container
cd ../external/postgres
docker-compose down

# Optional: Remove the Docker network
docker network rm k8s-network

# Optional: Remove built images from local Docker
docker rmi api-service:latest
docker rmi data-service:latest
docker rmi localhost:5000/api-service:latest
docker rmi localhost:5000/data-service:latest
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
# If missing, create it: docker network create k8s-network
```

**Delete and recreate cluster:**
```bash
k3d cluster delete k3d-local-dev
k3d cluster create --config cluster-config.yaml
```

### Pods stuck in ImagePullBackOff

**Issue**: Images not pushed to registry

**Check registry is running:**
```bash
docker ps | grep registry.localhost
```

**Verify images exist locally:**
```bash
docker images | grep service
```

**Check images are in registry:**
```bash
curl http://localhost:5000/v2/_catalog
```

**If images are missing, rebuild and push:**
```bash
# Rebuild images
docker build -t api-service:latest ../services/api-service
docker build -t data-service:latest ../services/data-service

# Tag and push
docker tag api-service:latest localhost:5000/api-service:latest
docker push localhost:5000/api-service:latest
docker tag data-service:latest localhost:5000/data-service:latest
docker push localhost:5000/data-service:latest

# Restart deployments
kubectl rollout restart deployment/api-service -n dev
kubectl rollout restart deployment/data-service -n dev
```

### Pods stuck in CrashLoopBackOff

**Check pod logs:**
```bash
kubectl logs <pod-name> -n dev
kubectl describe pod <pod-name> -n dev
```

**Common issues:**
- Database not accessible (check host.k3d.internal resolution)
- Configuration errors (check ConfigMap and Secrets)
- Resource limits too low (increase in deployment YAML)

**Check previous pod logs if pod restarted:**
```bash
kubectl logs <pod-name> -n dev --previous
```

### Data service can't connect to PostgreSQL

**Check PostgreSQL is running:**
```bash
docker ps | grep postgres-devdb
```

**Test connectivity from host:**
```bash
# Using psql
psql -h localhost -p 5432 -U postgres -d devdb
# Password: postgres

# Or using Docker
docker exec -it postgres-devdb psql -U postgres -d devdb
```

**Check k3d can resolve host:**
```bash
DATA_POD=$(kubectl get pods -n dev -l app=data-service -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $DATA_POD -n dev -- nslookup host.k3d.internal
```

**Verify environment variables in pod:**
```bash
kubectl exec $DATA_POD -n dev -- env | grep DB_
```

**Check data-service logs for connection errors:**
```bash
kubectl logs $DATA_POD -n dev | grep -i "connection\|database\|postgres"
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

**Test service directly without ingress:**
```bash
# Port-forward to api-service
kubectl port-forward svc/api-service 8000:8000 -n dev

# In another terminal, test
curl http://localhost:8000/api/health
```

**Check Traefik logs:**
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

### Port 80 already in use

**Find process using port 80:**
```bash
# macOS/Linux
lsof -i :80

# Or
sudo netstat -tulpn | grep :80
```

**Option 1: Stop the conflicting service**

**Option 2: Use different port** - Edit `cluster-config.yaml`:
```yaml
ports:
  - port: 8080:80
    nodeFilters:
      - loadbalancer
```

Then recreate cluster and access via http://localhost:8080/api

### Registry not accessible

**Check registry container:**
```bash
docker ps | grep registry.localhost
```

**Test registry API:**
```bash
curl http://localhost:5000/v2/
# Should return: {}
```

**Check registry logs:**
```bash
docker logs k3d-registry.localhost
```

**Restart cluster (includes registry):**
```bash
k3d cluster stop k3d-local-dev
k3d cluster start k3d-local-dev
```

### Image pull errors

**View detailed error:**
```bash
kubectl describe pod <pod-name> -n dev
# Look for "Events" section
```

**Common causes:**
1. Image not in registry - push it again
2. Wrong image name in deployment - check deployment YAML
3. Registry not accessible from cluster - check registry container

**Force pull new image:**
```bash
# Delete pods to force recreation and image pull
kubectl delete pods -l app=api-service -n dev
```

## Performance Tuning

### Reduce Resource Usage

Edit deployments to use fewer resources:

```bash
# Edit deployment
kubectl edit deployment api-service -n dev

# Change resources section:
# resources:
#   requests:
#     memory: "64Mi"
#     cpu: "50m"
#   limits:
#     memory: "128Mi"
#     cpu: "200m"
```

### Reduce Replica Count

For resource-constrained environments:

```bash
# Scale down to 1 replica
kubectl scale deployment api-service --replicas=1 -n dev
kubectl scale deployment data-service --replicas=1 -n dev

# Verify
kubectl get deployments -n dev
```

### Disable Metrics Server

Already configured in `cluster-config.yaml`:
```yaml
- arg: --disable=metrics-server
  nodeFilters:
    - server:*
```

## k3d vs Minikube vs kind

### k3d Advantages
✓ Fastest startup time (~30s)
✓ Lowest resource usage
✓ Built-in Traefik ingress
✓ Built-in local registry support
✓ Easy multi-node clusters
✓ Native Docker integration
✓ Production-like registry workflow

### k3d Considerations
- Different from production k8s (k3s is minimal)
- Limited to Docker driver
- Some k8s features removed in k3s

## Learning Objectives

By working through this setup, you'll learn:

1. **k3d cluster creation** using configuration files
2. **Docker registry workflows** for realistic development
3. **Multi-tier application deployment** in Kubernetes
4. **Service-to-service communication** within k8s
5. **External service connectivity** (k8s to external Docker containers)
6. **Ingress configuration** with Traefik
7. **Resource management** and scaling
8. **Troubleshooting** common k8s issues
9. **kubectl commands** for debugging and monitoring

## Additional Resources

- [k3d Documentation](https://k3d.io/)
- [k3s Documentation](https://docs.k3s.io/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## Next Steps

- [Configure Minikube Setup](../minikube-setup/README.md)
- [Configure kind Setup](../kind-setup/README.md)
- Compare all three tools and understand their differences
