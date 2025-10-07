#!/bin/bash
# Minikube Testing Script
# Validates the deployed three-tier application

set -e; set -u

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

PROFILE_NAME="minikube-local-dev"; NAMESPACE="dev"; TESTS_PASSED=0; TESTS_FAILED=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

test_result() { if [ $1 -eq 0 ]; then log_success "$2"; ((TESTS_PASSED++)); else log_error "$2"; ((TESTS_FAILED++)); fi; }

test_cluster_exists() {
    log_info "Testing: Cluster exists"
    if minikube profile list 2>/dev/null | grep -q "$PROFILE_NAME"; then test_result 0 "Cluster exists"; else test_result 1 "Cluster not found"; exit 1; fi
}

test_cluster_status() {
    log_info "Testing: Cluster is running"
    STATUS=$(minikube status --profile="$PROFILE_NAME" --format='{{.Host}}' 2>/dev/null || echo "")
    if [ "$STATUS" = "Running" ]; then test_result 0 "Cluster is running"; else test_result 1 "Cluster not running"; fi
}

test_namespace_exists() {
    log_info "Testing: Namespace exists"
    kubectl get namespace "$NAMESPACE" &>/dev/null && test_result 0 "Namespace exists" || test_result 1 "Namespace not found"
}

test_pods_running() {
    log_info "Testing: Pods are running"
    NOT_RUNNING=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    if [ "$NOT_RUNNING" -eq 0 ]; then
        TOTAL=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
        test_result 0 "All $TOTAL pods running"; echo; kubectl get pods -n "$NAMESPACE"; echo
    else
        test_result 1 "Some pods not running"; echo; kubectl get pods -n "$NAMESPACE"; echo
    fi
}

test_pods_ready() {
    log_info "Testing: Pods are ready"
    DATA_READY=$(kubectl get deployment data-service -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DATA_DESIRED=$(kubectl get deployment data-service -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    [ "$DATA_READY" -eq "$DATA_DESIRED" ] && [ "$DATA_READY" -gt 0 ] && test_result 0 "data-service: $DATA_READY/$DATA_DESIRED ready" || test_result 1 "data-service: $DATA_READY/$DATA_DESIRED ready"

    API_READY=$(kubectl get deployment api-service -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    API_DESIRED=$(kubectl get deployment api-service -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    [ "$API_READY" -eq "$API_DESIRED" ] && [ "$API_READY" -gt 0 ] && test_result 0 "api-service: $API_READY/$API_DESIRED ready" || test_result 1 "api-service: $API_READY/$API_DESIRED ready"
}

test_services_exist() {
    log_info "Testing: Services exist"
    kubectl get service api-service -n "$NAMESPACE" &>/dev/null && test_result 0 "api-service exists" || test_result 1 "api-service not found"
    kubectl get service data-service -n "$NAMESPACE" &>/dev/null && test_result 0 "data-service exists" || test_result 1 "data-service not found"
}

test_ingress_exists() {
    log_info "Testing: Ingress exists"
    kubectl get ingress api-ingress -n "$NAMESPACE" &>/dev/null && test_result 0 "Ingress exists" || test_result 1 "Ingress not found"
}

test_ingress_addon() {
    log_info "Testing: Ingress addon enabled"
    INGRESS_STATUS=$(minikube addons list --profile="$PROFILE_NAME" 2>/dev/null | grep "^| ingress " | awk '{print $3}' || echo "")
    [ "$INGRESS_STATUS" = "enabled" ] && test_result 0 "Ingress addon enabled" || test_result 1 "Ingress addon not enabled"
}

test_api_health() {
    log_info "Testing: API health endpoint"
    MINIKUBE_IP=$(minikube ip --profile="$PROFILE_NAME" 2>/dev/null || echo "")
    if [ -z "$MINIKUBE_IP" ]; then log_warn "Cannot get minikube IP"; return; fi
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$MINIKUBE_IP/api/health" 2>/dev/null || echo "000")
    [ "$HTTP_CODE" -eq 200 ] && test_result 0 "API health returned 200" || test_result 1 "API health returned $HTTP_CODE"
}

test_api_users() {
    log_info "Testing: API users endpoint"
    MINIKUBE_IP=$(minikube ip --profile="$PROFILE_NAME" 2>/dev/null || echo "")
    if [ -z "$MINIKUBE_IP" ]; then log_warn "Cannot get minikube IP"; return; fi
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$MINIKUBE_IP/api/users" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" -eq 200 ]; then
        test_result 0 "API users returned 200"
        log_info "Response sample:"; curl -s "http://$MINIKUBE_IP/api/users" 2>/dev/null | head -n 20; echo
    else
        test_result 1 "API users returned $HTTP_CODE"
    fi
}

test_database_connectivity() {
    log_info "Testing: Database connectivity"
    POD=$(kubectl get pods -n "$NAMESPACE" -l app=data-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -z "$POD" ]; then test_result 1 "No data-service pod"; return; fi
    LOGS=$(kubectl logs "$POD" -n "$NAMESPACE" --tail=100 2>/dev/null || echo "")
    if echo "$LOGS" | grep -qi "error.*database\|connection.*refused"; then
        test_result 1 "Database connection errors"; log_warn "Logs:"; echo "$LOGS" | tail -n 10
    else
        test_result 0 "No database errors"
    fi
}

test_postgres_running() {
    log_info "Testing: PostgreSQL running"
    docker ps --format '{{.Names}}' | grep -q "postgres-devdb" && test_result 0 "PostgreSQL running" || test_result 1 "PostgreSQL not running"
}

test_host_access() {
    log_info "Testing: host.minikube.internal resolution"
    POD=$(kubectl get pods -n "$NAMESPACE" -l app=data-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -z "$POD" ]; then log_warn "No pod for test"; return; fi
    kubectl exec "$POD" -n "$NAMESPACE" -- getent hosts host.minikube.internal &>/dev/null && test_result 0 "host.minikube.internal resolves" || test_result 1 "host resolution failed"
}

display_summary() {
    echo; echo "========================================"; echo "           Test Summary"
    echo "========================================"; log_success "Passed: $TESTS_PASSED"; log_error "Failed: $TESTS_FAILED"
    echo "========================================"; echo
    if [ $TESTS_FAILED -eq 0 ]; then log_success "All tests passed! ✓"; return 0
    else log_error "Some tests failed"; log_info "Troubleshooting:"; echo "  minikube status --profile=$PROFILE_NAME"
        echo "  kubectl get pods -n $NAMESPACE"; echo "  kubectl logs <pod-name> -n $NAMESPACE"; return 1; fi
}

main() {
    echo "========================================"; echo "   Minikube Application Test Suite"; echo "========================================"
    echo; test_cluster_exists; echo; test_cluster_status; echo; test_namespace_exists; echo
    test_pods_running; echo; test_pods_ready; echo; test_services_exist; echo; test_ingress_exists; echo
    test_ingress_addon; echo; test_postgres_running; echo; test_host_access; echo
    test_api_health; echo; test_api_users; echo; test_database_connectivity; echo; display_summary
}

main "$@"
