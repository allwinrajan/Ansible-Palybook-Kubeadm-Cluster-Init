#!/bin/bash
# Kubernetes DNS Verification Script
# Run this after cluster setup to verify DNS is working

set -e

echo "=========================================="
echo "Kubernetes DNS Verification Test"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
PASSED=0
FAILED=0

# Function to print test result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED${NC}: $2"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}: $2"
        ((FAILED++))
    fi
}

echo "1. Checking CoreDNS pods..."
if kubectl get pods -n kube-system -l k8s-app=kube-dns | grep -q "Running"; then
    COUNT=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep "Running" | wc -l)
    if [ "$COUNT" -ge 2 ]; then
        print_result 0 "CoreDNS pods running ($COUNT pods)"
    else
        print_result 1 "Not enough CoreDNS pods running (found $COUNT, expected 2)"
    fi
else
    print_result 1 "CoreDNS pods not running"
fi

echo ""
echo "2. Checking kube-dns service..."
if kubectl get svc -n kube-system kube-dns | grep -q "10.96.0.10"; then
    print_result 0 "kube-dns service exists with correct ClusterIP"
else
    print_result 1 "kube-dns service not found or wrong IP"
fi

echo ""
echo "3. Testing internal DNS resolution (kubernetes.default)..."
if kubectl run dns-test-1 --image=busybox:1.28 --rm -i --restart=Never --command -- nslookup kubernetes.default > /dev/null 2>&1; then
    print_result 0 "Internal DNS resolution works"
else
    print_result 1 "Internal DNS resolution failed"
fi

echo ""
echo "4. Testing external DNS resolution (google.com)..."
if kubectl run dns-test-2 --image=busybox:1.28 --rm -i --restart=Never --command -- nslookup google.com > /dev/null 2>&1; then
    print_result 0 "External DNS resolution works"
else
    print_result 1 "External DNS resolution failed"
fi

echo ""
echo "5. Testing package manager (apt update in Ubuntu pod)..."
if kubectl run apt-test --image=ubuntu:22.04 --rm -i --restart=Never --command -- bash -c "apt update > /dev/null 2>&1"; then
    print_result 0 "apt update works (DNS + internet access)"
else
    print_result 1 "apt update failed"
fi

echo ""
echo "6. Deploying test service..."
kubectl create deployment dns-verify-nginx --image=nginx:alpine > /dev/null 2>&1 || true
kubectl expose deployment dns-verify-nginx --port=80 --name=dns-verify-svc > /dev/null 2>&1 || true
sleep 5

echo "7. Testing service DNS resolution..."
if kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never --command -- curl -s dns-verify-svc.default.svc.cluster.local > /dev/null 2>&1; then
    print_result 0 "Service DNS resolution works"
else
    print_result 1 "Service DNS resolution failed"
fi

echo ""
echo "8. Cleaning up test resources..."
kubectl delete deployment dns-verify-nginx > /dev/null 2>&1 || true
kubectl delete svc dns-verify-svc > /dev/null 2>&1 || true
echo -e "${GREEN}✓${NC} Cleanup complete"

echo ""
echo "=========================================="
echo "TEST SUMMARY"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "=========================================="

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED - DNS IS WORKING CORRECTLY${NC}"
    echo ""
    echo "Your cluster has:"
    echo "  ✓ Working CoreDNS"
    echo "  ✓ Internal DNS resolution"
    echo "  ✓ External DNS resolution"
    echo "  ✓ Service discovery"
    echo "  ✓ Internet access from pods"
    echo "  ✓ Package manager functionality"
    echo ""
    echo "Cluster is PRODUCTION READY!"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED - DNS ISSUES DETECTED${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check CoreDNS logs:"
    echo "   kubectl logs -n kube-system -l k8s-app=kube-dns"
    echo ""
    echo "2. Restart CoreDNS:"
    echo "   kubectl rollout restart deployment/coredns -n kube-system"
    echo ""
    echo "3. Check Calico:"
    echo "   kubectl get pods -n calico-system"
    echo ""
    echo "4. Check node status:"
    echo "   kubectl get nodes"
    exit 1
fi
