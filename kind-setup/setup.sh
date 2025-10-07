#!/bin/bash
# kind Cluster Setup Script
# Creates a kind cluster and deploys the three-tier microservices application
#
# Prerequisites:
# - kind installed
# - kubectl installed
# - Docker running
# - PostgreSQL container running on k8s-network

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="kind-local-dev"
CONFIG_FILE="cluster-config.yaml"
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

    # Check kind
    if ! command -v kind &> /dev/null; then
        log_error "kind is not installed. Install: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        exit 1
    fi
    log_success "kind found: $(kind version)"

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

    # Check if k8s-network exists
    if ! docker network inspect k8s-network &> /dev/null; then
        log_warn "k8s-network does not exist. Creating it..."
        docker network create k8s-network
        log_success "Created k8s-network"
    else
        log_success "k8s-network exists"
    fi

    # Check if PostgreSQL is running
    if ! docker ps --format '{{.Names}}' | grep -q "postgres-devdb"; then
        log_warn "PostgreSQL container not running. Starting it..."
        (cd "$PROJECT_ROOT/external/postgres" && docker-compose up -d)
        sleep 5
        log_success "PostgreSQL started"
    else
        log_success "PostgreSQL is running"
    fi
}

# Check if cluster already exists
check_cluster_exists() {
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log_warn "Cluster '$CLUSTER_NAME' already exists"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting existing cluster..."
            kind delete cluster --name "$CLUSTER_NAME"
            log_success "Cluster deleted"
        else
            log_info "Using existing cluster"
            return 0
        fi
    fi
    return 1
}

# Create kind cluster
create_cluster() {
    log_info "Creating kind cluster '$CLUSTER_NAME'..."

    cd "$SCRIPT_DIR"
    kind create cluster --config "$CONFIG_FILE"

    log_success "Cluster created successfully"

    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=120s
    log_success "Cluster is ready"
}

# Connect kind network to k8s-network
connect_network() {
    log_info "Connecting kind cluster to k8s-network..."

    # Get the kind container names
    local containers=$(docker ps --filter "name=${CLUSTER_NAME}" --format "{{.Names}}")

    for container in $containers; do
        # Check if already connected
        if docker inspect "$container" --format '{{range $net, $v := .NetworkSettings.Networks}}{{$net}} {{end}}' | grep -q "k8s-network"; then
            log_info "Container $container already connected to k8s-network"
        else
            docker network connect k8s-network "$container"
            log_success "Connected $container to k8s-network"
        fi
    done
}

# Install NGINX Ingress Controller
install_ingress() {
    log_info "Installing NGINX Ingress Controller..."

    # Apply the NGINX ingress controller manifest
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    log_success "NGINX Ingress Controller installed"

    # Wait for ingress controller to be ready
    log_info "Waiting for NGINX Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s

    log_success "NGINX Ingress Controller is ready"
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

# Load images to kind
load_images() {
    log_info "Loading images to kind cluster..."

    kind load docker-image api-service:latest --name "$CLUSTER_NAME"
    log_success "api-service loaded"

    kind load docker-image data-service:latest --name "$CLUSTER_NAME"
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
    log_success "kind Cluster Setup Complete!"
    log_success "==================================="
    echo
    log_info "Cluster: $CLUSTER_NAME"
    log_info "Namespace: $NAMESPACE"
    log_info "Kubeconfig: $HOME/.kube/config"
    echo
    log_info "Access the API:"
    echo "  curl http://localhost/api/health"
    echo "  curl http://localhost/api/users"
    echo
    log_info "Useful commands:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  kubectl get svc -n $NAMESPACE"
    echo "  kubectl logs -f deployment/api-service -n $NAMESPACE"
    echo "  kubectl logs -f deployment/data-service -n $NAMESPACE"
    echo
    log_info "To delete the cluster:"
    echo "  kind delete cluster --name $CLUSTER_NAME"
    echo
}

# Main execution
main() {
    log_info "Starting kind cluster setup..."
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

        connect_network
        echo

        install_ingress
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
