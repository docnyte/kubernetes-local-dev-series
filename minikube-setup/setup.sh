#!/bin/bash
# Minikube Cluster Setup Script
# Creates a minikube cluster and deploys the three-tier microservices application
#
# Prerequisites:
# - minikube installed
# - kubectl installed
# - Docker running
# - PostgreSQL container running (accessible on host)

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROFILE_NAME="minikube-local-dev"
DRIVER="docker"
NODES=3
CPUS=4
MEMORY=4096
DISK_SIZE="20g"
NAMESPACE="dev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check minikube
    if ! command -v minikube &> /dev/null; then
        log_error "minikube is not installed. Install: https://minikube.sigs.k8s.io/docs/start/"
        exit 1
    fi
    log_success "minikube found: $(minikube version --short)"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Install: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    log_success "kubectl found: $(kubectl version --client -o json | grep -o '"gitVersion":"[^"]*"' | cut -d'"' -f4)"

    # Check Docker
    if ! docker ps &> /dev/null; then
        log_error "Docker is not running. Please start Docker."
        exit 1
    fi
    log_success "Docker is running"

    # Check if PostgreSQL is running
    if ! docker ps --format '{{.Names}}' | grep -q "postgres-devdb"; then
        log_warn "PostgreSQL container not running. Starting it..."
        (cd "$PROJECT_ROOT/external/postgres" && docker-compose up -d)
        sleep 5
        log_success "PostgreSQL started"
    else
        log_success "PostgreSQL is running"
    fi

    # Verify PostgreSQL is listening on all interfaces
    log_info "Checking PostgreSQL network binding..."
    POSTGRES_BIND=$(docker exec postgres-devdb psql -U postgres -t -c "SHOW listen_addresses;" 2>/dev/null | tr -d ' ' || echo "")
    if [ "$POSTGRES_BIND" != "*" ] && [ "$POSTGRES_BIND" != "0.0.0.0" ]; then
        log_warn "PostgreSQL may not be accessible from minikube (listen_addresses='$POSTGRES_BIND')"
        log_warn "Ensure PostgreSQL is configured to listen on all interfaces"
    else
        log_success "PostgreSQL is configured correctly"
    fi
}

# Check if cluster already exists
check_cluster_exists() {
    if minikube profile list 2>/dev/null | grep -q "$PROFILE_NAME"; then
        log_warn "Cluster '$PROFILE_NAME' already exists"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting existing cluster..."
            minikube delete --profile "$PROFILE_NAME"
            log_success "Cluster deleted"
        else
            log_info "Using existing cluster"
            return 0
        fi
    fi
    return 1
}

# Create minikube cluster
create_cluster() {
    log_info "Creating minikube cluster '$PROFILE_NAME'..."

    minikube start \
        --profile="$PROFILE_NAME" \
        --driver="$DRIVER" \
        --nodes="$NODES" \
        --cpus="$CPUS" \
        --memory="$MEMORY" \
        --disk-size="$DISK_SIZE" \
        --kubernetes-version=stable

    log_success "Cluster created successfully"

    # Set context
    kubectl config use-context "$PROFILE_NAME"
    log_success "Kubectl context set to $PROFILE_NAME"

    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=120s
    log_success "Cluster is ready"
}

# Enable addons
enable_addons() {
    log_info "Enabling minikube addons..."

    # Enable ingress addon (NGINX)
    log_info "Enabling ingress addon..."
    minikube addons enable ingress --profile="$PROFILE_NAME"
    log_success "Ingress addon enabled"

    # Enable metrics-server addon
    log_info "Enabling metrics-server addon..."
    minikube addons enable metrics-server --profile="$PROFILE_NAME"
    log_success "Metrics-server addon enabled"

    # Wait for ingress controller to be ready
    log_info "Waiting for NGINX Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s 2>/dev/null || log_warn "Ingress controller may still be starting"
    log_success "Ingress addon is ready"
}

# Build Docker images
build_images() {
    log_info "Building Docker images..."

    # Build API service
    log_info "Building api-service..."
    docker build -t api-service:latest "$PROJECT_ROOT/services/api-service"
    log_success "api-service built"

    # Build Data service
    log_info "Building data-service..."
    docker build -t data-service:latest "$PROJECT_ROOT/services/data-service"
    log_success "data-service built"
}

# Load images to minikube
load_images() {
    log_info "Loading images to minikube cluster..."

    # Load images using minikube image load
    log_info "Loading api-service..."
    minikube image load api-service:latest --profile="$PROFILE_NAME"
    log_success "api-service loaded"

    log_info "Loading data-service..."
    minikube image load data-service:latest --profile="$PROFILE_NAME"
    log_success "data-service loaded"
}

# Deploy Kubernetes resources
deploy_resources() {
    log_info "Deploying Kubernetes resources..."

    cd "$SCRIPT_DIR/manifests"

    # Apply manifests in order
    log_info "Creating namespace..."
    kubectl apply -f namespace.yaml

    log_info "Creating ConfigMap and Secrets..."
    kubectl apply -f configmap.yaml
    kubectl apply -f secrets.yaml

    log_info "Deploying services..."
    kubectl apply -f data-deployment.yaml
    kubectl apply -f api-deployment.yaml

    log_info "Creating Kubernetes Services..."
    kubectl apply -f services.yaml

    log_info "Creating Ingress..."
    kubectl apply -f ingress.yaml

    log_success "Resources deployed"
}

# Wait for deployments
wait_for_deployments() {
    log_info "Waiting for deployments to be ready..."

    # Wait for data-service
    log_info "Waiting for data-service..."
    kubectl rollout status deployment/data-service -n "$NAMESPACE" --timeout=300s
    log_success "data-service is ready"

    # Wait for api-service
    log_info "Waiting for api-service..."
    kubectl rollout status deployment/api-service -n "$NAMESPACE" --timeout=300s
    log_success "api-service is ready"
}

# Display cluster info
display_info() {
    log_success "==================================="
    log_success "Minikube Cluster Setup Complete!"
    log_success "==================================="
    echo
    log_info "Cluster: $PROFILE_NAME"
    log_info "Namespace: $NAMESPACE"
    log_info "Driver: $DRIVER"
    log_info "Nodes: $NODES"
    echo

    # Get minikube IP
    MINIKUBE_IP=$(minikube ip --profile="$PROFILE_NAME" 2>/dev/null || echo "N/A")
    log_info "Minikube IP: $MINIKUBE_IP"
    echo

    log_info "Access the API:"
    if [ "$MINIKUBE_IP" != "N/A" ]; then
        echo "  curl http://$MINIKUBE_IP/api/health"
        echo "  curl http://$MINIKUBE_IP/api/users"
    else
        echo "  Use 'minikube service' or 'minikube tunnel' to access services"
    fi
    echo

    log_info "Alternative access methods:"
    echo "  # Using minikube tunnel (requires sudo, run in separate terminal):"
    echo "  minikube tunnel --profile=$PROFILE_NAME"
    echo "  # Then access: curl http://localhost/api/health"
    echo
    echo "  # Using minikube service:"
    echo "  minikube service api-service -n $NAMESPACE --profile=$PROFILE_NAME --url"
    echo

    log_info "Useful commands:"
    echo "  minikube status --profile=$PROFILE_NAME"
    echo "  minikube dashboard --profile=$PROFILE_NAME"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  kubectl get svc -n $NAMESPACE"
    echo "  kubectl logs -f deployment/api-service -n $NAMESPACE"
    echo "  kubectl logs -f deployment/data-service -n $NAMESPACE"
    echo

    log_info "To delete the cluster:"
    echo "  minikube delete --profile=$PROFILE_NAME"
    echo
}

# Main execution
main() {
    log_info "Starting minikube cluster setup..."
    echo

    check_prerequisites
    echo

    CLUSTER_EXISTS=false
    if check_cluster_exists; then
        CLUSTER_EXISTS=true
    fi
    echo

    if [ "$CLUSTER_EXISTS" = false ]; then
        create_cluster
        echo

        enable_addons
        echo
    fi

    build_images
    echo

    load_images
    echo

    deploy_resources
    echo

    wait_for_deployments
    echo

    display_info
}

# Run main function
main "$@"
