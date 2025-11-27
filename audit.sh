#!/bin/bash

# Kube-Simple-Audit
# A lightweight sanity check for Kubernetes clusters.
# https://run-as-daemon.dev

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting Kube-Simple-Audit...${NC}"

# Check dependencies
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed.${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed.${NC}"
    exit 1
fi

# 1. Privileged Pods
echo -e "\n${YELLOW}[1/4] Checking for Privileged Pods...${NC}"
PRIVILEGED=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[].securityContext.privileged == true) | "\(.metadata.namespace)/\(.metadata.name)"')

if [ -z "$PRIVILEGED" ]; then
    echo -e "${GREEN}✅ No privileged pods found.${NC}"
else
    echo -e "${RED}❌ Found privileged pods:${NC}"
    echo "$PRIVILEGED"
fi

# 2. Root Containers (UID 0 or missing runAsNonRoot)
echo -e "\n${YELLOW}[2/4] Checking for Root Containers...${NC}"
# Logic: Check if runAsNonRoot is NOT true (null or false) AND (runAsUser is 0 or null)
# Note: This is a simplified check. A proper check would need to inspect image metadata which is hard with just kubectl/jq.
# We will check explicit securityContext settings.
ROOT_PODS=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(
    (.spec.securityContext.runAsNonRoot != true) and 
    (.spec.containers[].securityContext.runAsNonRoot != true)
) | "\(.metadata.namespace)/\(.metadata.name)"')

if [ -z "$ROOT_PODS" ]; then
    echo -e "${GREEN}✅ No obvious root containers found (based on securityContext).${NC}"
else
    echo -e "${RED}❌ Found pods potentially running as root (missing runAsNonRoot):${NC}"
    # Show top 5 to avoid spamming
    echo "$ROOT_PODS" | head -n 5
    if [ $(echo "$ROOT_PODS" | wc -l) -gt 5 ]; then echo "...and more"; fi
fi

# 3. Resource Limits
echo -e "\n${YELLOW}[3/4] Checking for Missing Resource Limits...${NC}"
NO_LIMITS=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[].resources.limits == null) | "\(.metadata.namespace)/\(.metadata.name)"')

if [ -z "$NO_LIMITS" ]; then
    echo -e "${GREEN}✅ All pods have resource limits defined.${NC}"
else
    echo -e "${RED}❌ Found pods without resource limits:${NC}"
    echo "$NO_LIMITS" | head -n 5
    if [ $(echo "$NO_LIMITS" | wc -l) -gt 5 ]; then echo "...and more"; fi
fi

# 4. Default Namespace
echo -e "\n${YELLOW}[4/4] Checking for Workloads in 'default' Namespace...${NC}"
DEFAULT_PODS=$(kubectl get pods -n default -o name)

if [ -z "$DEFAULT_PODS" ]; then
    echo -e "${GREEN}✅ No workloads found in 'default' namespace.${NC}"
else
    echo -e "${RED}❌ Found workloads in 'default' namespace:${NC}"
    echo "$DEFAULT_PODS" | head -n 5
    if [ $(echo "$DEFAULT_PODS" | wc -l) -gt 5 ]; then echo "...and more"; fi
fi

# Summary Box
echo -e "\n"
echo -e "${BLUE}################################################################${NC}"
echo -e "${BLUE}#                   Audit Complete                             #${NC}"
echo -e "${BLUE}################################################################${NC}"
echo -e "${YELLOW}Detected potential risks?${NC}"
echo -e "${YELLOW}Book a professional Deep-Dive Architecture Audit:${NC}"
echo -e "${GREEN}https://run-as-daemon.dev/en/services/express-audit-hardening.html${NC}"
echo -e "${BLUE}################################################################${NC}"
echo -e "\n"
