#!/bin/bash
# Task 7: Basic OpenShift Cluster Health Check

echo "========================================="
echo "OpenShift Cluster Health Check"
echo "========================================="
echo "Date: $(date)"
echo ""

# Variables
CLUSTER_NAME="ocp-cluster"
BASE_DOMAIN="nutanix.local"
DNS_SERVER="10.11.1.63"
API_VIP="10.11.1.42"
INGRESS_VIP="10.11.1.43"

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper functions
print_check() {
    echo -n "Checking $1... "
}

print_ok() {
    echo -e "${GREEN}[OK]${NC}"
}

print_fail() {
    echo -e "${RED}[FAILED]${NC}"
    echo "  Error: $1"
}

print_section() {
    echo ""
    echo "======================================"
    echo "$1"
    echo "======================================"
}

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    INSTALL_DIR=$(cat /home/nutanix/.openshift_install_dir 2>/dev/null)
    if [ -n "$INSTALL_DIR" ]; then
        export KUBECONFIG="${INSTALL_DIR}/auth/kubeconfig"
    else
        echo "ERROR: KUBECONFIG not set and cannot find installation directory"
        exit 1
    fi
fi

# Initialize counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# 1. Basic Connectivity Check
print_section "1. Basic Connectivity Check"

# Ping API VIP
print_check "API VIP connectivity ($API_VIP)"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if ping -c 3 -W 5 "$API_VIP" &>/dev/null; then
    print_ok
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    print_fail "Cannot ping API VIP"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Ping Ingress VIP
print_check "Ingress VIP connectivity ($INGRESS_VIP)"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if ping -c 3 -W 5 "$INGRESS_VIP" &>/dev/null; then
    print_ok
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    print_fail "Cannot ping Ingress VIP"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# 2. DNS Resolution Check
print_section "2. DNS Resolution Check"

# Check API endpoint
API_ENDPOINT="api.${CLUSTER_NAME}.${BASE_DOMAIN}"
print_check "DNS resolution for $API_ENDPOINT"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if nslookup "$API_ENDPOINT" "$DNS_SERVER" &>/dev/null; then
    print_ok
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    print_fail "DNS resolution failed for API endpoint"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check Apps wildcard endpoint
APPS_ENDPOINT="test.apps.${CLUSTER_NAME}.${BASE_DOMAIN}"
print_check "DNS resolution for apps wildcard (*.apps.${CLUSTER_NAME}.${BASE_DOMAIN})"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if nslookup "$APPS_ENDPOINT" "$DNS_SERVER" &>/dev/null; then
    print_ok
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    print_fail "DNS resolution failed for apps wildcard"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# 3. API Server Basic Check
print_section "3. API Server Basic Check"

print_check "API server connectivity"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if oc get --raw /healthz &>/dev/null; then
    print_ok
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    print_fail "Cannot connect to API server"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# 4. Basic Node Status Check
print_section "4. Basic Node Status Check"

print_check "Node availability"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if oc get nodes &>/dev/null; then
    TOTAL_NODES=$(oc get nodes --no-headers 2>/dev/null | wc -l)
    if [ "$TOTAL_NODES" -gt 0 ]; then
        print_ok
        echo "  Found $TOTAL_NODES nodes"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        print_fail "No nodes found"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    print_fail "Cannot retrieve node information"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Generate Summary
print_section "Health Check Summary"
echo ""
echo "Total Checks: $TOTAL_CHECKS"
echo "Passed: $PASSED_CHECKS"
echo "Failed: $FAILED_CHECKS"
echo ""

# Overall status
if [ "$FAILED_CHECKS" -eq 0 ]; then
    echo -e "Overall Status: ${GREEN}HEALTHY${NC}"
    echo ""
    echo "The OpenShift cluster basic health checks passed."
else
    echo -e "Overall Status: ${RED}UNHEALTHY${NC}"
    echo ""
    echo "The OpenShift cluster has $FAILED_CHECKS critical issues."
fi

echo ""
echo "======================================"
echo "Health check completed!"
echo "======================================"

# Exit with appropriate code
if [ "$FAILED_CHECKS" -gt 0 ]; then
    exit 1
else
    exit 0
fi
