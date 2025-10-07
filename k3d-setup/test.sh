#!/bin/bash
# k3d Testing Script
# Validates the deployed three-tier application
#
# This script tests:
# 1. Cluster and namespace existence
# 2. Pod health and readiness
# 3. Service endpoints
# 4. API health endpoint
# 5. Full request flow (API → Data → PostgreSQL)

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="k3d-local-dev"
NAMESPACE="dev"
API_URL="http://localhost/api"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
test_result() {
    if [ $1 -eq 0 ]; then
        log_success "$2"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$2"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Check if cluster exists
test_cluster_exists() {
    log_info "Testing: Cluster exists"
    if k3d cluster list | grep -q "$CLUSTER_NAME"; then
        test_result 0 "Cluster '$CLUSTER_NAME' exists"
    else
        test_result 1 "Cluster '$CLUSTER_NAME' does not exist"
        exit 1
    fi
}

# Check if namespace exists
test_namespace_exists() {
    log_info "Testing: Namespace exists"
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        test_result 0 "Namespace '$NAMESPACE' exists"
    else
        test_result 1 "Namespace '$NAMESPACE' does not exist"
    fi
}

# Check if all pods are running
test_pods_running() {
    log_info "Testing: Pods are running"

    # Get pod status
    NOT_RUNNING=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)

    if [ "$NOT_RUNNING" -eq 0 ]; then
        TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
        test_result 0 "All $TOTAL_PODS pods are running"

        # Display pod status
        echo
        kubectl get pods -n "$NAMESPACE"
        echo
    else
        test_result 1 "Some pods are not running"
        echo
        kubectl get pods -n "$NAMESPACE"
        echo
    fi
}

# Check if pods are ready
test_pods_ready() {
    log_info "Testing: Pods are ready"

    # Check data-service
    DATA_READY=$(kubectl get deployment data-service -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DATA_DESIRED=$(kubectl get deployment data-service -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

    if [ "$DATA_READY" -eq "$DATA_DESIRED" ] && [ "$DATA_READY" -gt 0 ]; then
        test_result 0 "data-service: $DATA_READY/$DATA_DESIRED replicas ready"
    else
        test_result 1 "data-service: $DATA_READY/$DATA_DESIRED replicas ready"
    fi

    # Check api-service
    API_READY=$(kubectl get deployment api-service -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    API_DESIRED=$(kubectl get deployment api-service -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

    if [ "$API_READY" -eq "$API_DESIRED" ] && [ "$API_READY" -gt 0 ]; then
        test_result 0 "api-service: $API_READY/$API_DESIRED replicas ready"
    else
        test_result 1 "api-service: $API_READY/$API_DESIRED replicas ready"
    fi
}

# Check if services exist
test_services_exist() {
    log_info "Testing: Services exist"

    if kubectl get service api-service -n "$NAMESPACE" &> /dev/null; then
        test_result 0 "api-service service exists"
    else
        test_result 1 "api-service service does not exist"
    fi

    if kubectl get service data-service -n "$NAMESPACE" &> /dev/null; then
        test_result 0 "data-service service exists"
    else
        test_result 1 "data-service service does not exist"
    fi
}

# Check if ingress exists
test_ingress_exists() {
    log_info "Testing: Ingress exists"

    if kubectl get ingress api-ingress -n "$NAMESPACE" &> /dev/null; then
        test_result 0 "Ingress 'api-ingress' exists"
    else
        test_result 1 "Ingress 'api-ingress' does not exist"
    fi
}

# Test API health endpoint
test_api_health() {
    log_info "Testing: API health endpoint"

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" -eq 200 ]; then
        test_result 0 "API health endpoint returned 200"
    else
        test_result 1 "API health endpoint returned $HTTP_CODE (expected 200)"
    fi
}

# Test API users endpoint
test_api_users() {
    log_info "Testing: API users endpoint"

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/users" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" -eq 200 ]; then
        test_result 0 "API users endpoint returned 200"

        # Display response
        log_info "Response sample:"
        curl -s "$API_URL/users" | head -n 20
        echo
    else
        test_result 1 "API users endpoint returned $HTTP_CODE (expected 200)"
    fi
}

# Test database connectivity
test_database_connectivity() {
    log_info "Testing: Database connectivity from data-service"

    # Get a data-service pod name
    POD=$(kubectl get pods -n "$NAMESPACE" -l app=data-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [ -z "$POD" ]; then
        test_result 1 "No data-service pod found"
        return
    fi

    # Check logs for database connection errors
    LOGS=$(kubectl logs "$POD" -n "$NAMESPACE" --tail=100 2>/dev/null || echo "")

    if echo "$LOGS" | grep -qi "error.*database\|connection.*refused\|connection.*timeout"; then
        test_result 1 "Database connection errors found in logs"
        log_warn "Recent logs from $POD:"
        echo "$LOGS" | tail -n 10
    else
        test_result 0 "No database connection errors in logs"
    fi
}

# Check PostgreSQL container
test_postgres_running() {
    log_info "Testing: PostgreSQL container is running"

    if docker ps --format '{{.Names}}' | grep -q "postgres-devdb"; then
        test_result 0 "PostgreSQL container is running"
    else
        test_result 1 "PostgreSQL container is not running"
        log_warn "Start PostgreSQL: cd ../external/postgres && docker-compose up -d"
    fi
}

# Test local registry
test_registry_running() {
    log_info "Testing: Local registry is running"

    if docker ps --format '{{.Names}}' | grep -q "k3d-registry.localhost"; then
        test_result 0 "Local registry container is running"
    else
        test_result 1 "Local registry container is not running"
    fi
}

# Test registry accessibility
test_registry_accessible() {
    log_info "Testing: Registry is accessible"

    REGISTRY_URL="http://localhost:5000"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$REGISTRY_URL/v2/" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" -eq 200 ]; then
        test_result 0 "Registry API is accessible"
    else
        test_result 1 "Registry API returned $HTTP_CODE (expected 200)"
    fi
}

# Test images in registry
test_images_in_registry() {
    log_info "Testing: Images are in registry"

    CATALOG=$(curl -s http://localhost:5000/v2/_catalog 2>/dev/null || echo "")

    if echo "$CATALOG" | grep -q "api-service"; then
        test_result 0 "api-service image found in registry"
    else
        test_result 1 "api-service image not found in registry"
    fi

    if echo "$CATALOG" | grep -q "data-service"; then
        test_result 0 "data-service image found in registry"
    else
        test_result 1 "data-service image not found in registry"
    fi
}

# Display summary
display_summary() {
    echo
    echo "========================================"
    echo "           Test Summary"
    echo "========================================"
    log_success "Passed: $TESTS_PASSED"
    log_error "Failed: $TESTS_FAILED"
    echo "========================================"
    echo

    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed! ✓"
        return 0
    else
        log_error "Some tests failed. Check the output above for details."
        echo
        log_info "Troubleshooting commands:"
        echo "  kubectl get pods -n $NAMESPACE"
        echo "  kubectl describe pod <pod-name> -n $NAMESPACE"
        echo "  kubectl logs <pod-name> -n $NAMESPACE"
        echo "  kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
        return 1
    fi
}

# Main execution
main() {
    echo "========================================"
    echo "     k3d Application Test Suite"
    echo "========================================"
    echo

    test_cluster_exists
    echo

    test_namespace_exists
    echo

    test_pods_running
    echo

    test_pods_ready
    echo

    test_services_exist
    echo

    test_ingress_exists
    echo

    test_registry_running
    echo

    test_registry_accessible
    echo

    test_images_in_registry
    echo

    test_postgres_running
    echo

    test_api_health
    echo

    test_api_users
    echo

    test_database_connectivity
    echo

    display_summary
}

# Run main function
main "$@"
