#!/usr/bin/env bash
# Kube-Simple-Audit — 5-second Kubernetes security sanity check.
# https://github.com/ranas-mukminov/Kube-Simple-Audit
# https://run-as-daemon.dev
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MD_OUT="${AUDIT_MD:-}"
WRITE_SUMMARY="${GITHUB_STEP_SUMMARY:-}"
CTA_URL="https://run-as-daemon.dev/en/services/express-audit-hardening.html"
STARTER_URL="https://github.com/ranas-mukminov/Secure-K3s-GitOps-Template"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      MD_OUT="${2:-}"
      shift 2
      ;;
    --markdown)
      MD_OUT="${MD_OUT:-kube-simple-audit-report.md}"
      shift
      ;;
    -h|--help)
      echo "Usage: ./audit.sh [--markdown|-o FILE]"
      echo "  One-liner: curl -fsSL https://raw.githubusercontent.com/ranas-mukminov/Kube-Simple-Audit/main/audit.sh | bash"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

echo -e "${BLUE}Starting Kube-Simple-Audit...${NC}"

if ! command -v kubectl &>/dev/null; then
  echo -e "${RED}Error: kubectl is not installed.${NC}"
  exit 1
fi
if ! command -v jq &>/dev/null; then
  echo -e "${RED}Error: jq is not installed.${NC}"
  exit 1
fi

PRIVILEGED_COUNT=0
ROOT_COUNT=0
NO_LIMITS_COUNT=0
DEFAULT_COUNT=0
PRIVILEGED_SAMPLES=""
ROOT_SAMPLES=""
NO_LIMITS_SAMPLES=""
DEFAULT_SAMPLES=""

echo -e "\n${YELLOW}[1/4] Checking for Privileged Pods...${NC}"
# Include initContainers / ephemeralContainers — privileged sidecars otherwise hide.
PRIVILEGED=$(kubectl get pods --all-namespaces -o json \
  | jq -r '.items[] | select(any((.spec.containers + (.spec.initContainers // []) + (.spec.ephemeralContainers // []))[]?; .securityContext.privileged == true)) | "\(.metadata.namespace)/\(.metadata.name)"' \
  | sort -u || true)
if [[ -z "$PRIVILEGED" ]]; then
  echo -e "${GREEN}✅ No privileged pods found.${NC}"
else
  PRIVILEGED_COUNT=$(printf '%s\n' "$PRIVILEGED" | grep -c . || true)
  echo -e "${RED}❌ Found privileged pods (${PRIVILEGED_COUNT}):${NC}"
  PRIVILEGED_SAMPLES=$(printf '%s\n' "$PRIVILEGED" | head -n 5)
  echo "$PRIVILEGED_SAMPLES"
  if [[ "$PRIVILEGED_COUNT" -gt 5 ]]; then echo "...and more"; fi
fi

echo -e "\n${YELLOW}[2/4] Checking for Root Containers...${NC}"
# Prefer runAsUser when set: runAsUser>0 without runAsNonRoot is not "potential root".
# Flag pod if pod-level allows root AND any container/init/ephemeral looks root.
# (Previously used `all`, which skipped mixed pods with one hardened + one root container.)
ROOT_PODS=$(kubectl get pods --all-namespaces -o json \
  | jq -r '.items[] | select(
      ((.spec.securityContext.runAsNonRoot != true) and ((.spec.securityContext.runAsUser // 0) == 0))
      and (any((.spec.containers + (.spec.initContainers // []) + (.spec.ephemeralContainers // []))[]?;
            (.securityContext.runAsNonRoot != true)
            and ((.securityContext.runAsUser // 0) == 0)))
    ) | "\(.metadata.namespace)/\(.metadata.name)"' \
  | sort -u || true)
if [[ -z "$ROOT_PODS" ]]; then
  echo -e "${GREEN}✅ No obvious root containers found (based on securityContext).${NC}"
else
  ROOT_COUNT=$(printf '%s\n' "$ROOT_PODS" | grep -c . || true)
  echo -e "${RED}❌ Found pods potentially running as root (missing runAsNonRoot / runAsUser=0) (${ROOT_COUNT}):${NC}"
  ROOT_SAMPLES=$(printf '%s\n' "$ROOT_PODS" | head -n 5)
  echo "$ROOT_SAMPLES"
  if [[ "$ROOT_COUNT" -gt 5 ]]; then echo "...and more"; fi
fi

echo -e "\n${YELLOW}[3/4] Checking for Missing Resource Limits...${NC}"
NO_LIMITS=$(kubectl get pods --all-namespaces -o json \
  | jq -r '.items[] | select(any(.spec.containers[]?; .resources.limits == null)) | "\(.metadata.namespace)/\(.metadata.name)"' \
  | sort -u || true)
if [[ -z "$NO_LIMITS" ]]; then
  echo -e "${GREEN}✅ All pods have resource limits defined.${NC}"
else
  NO_LIMITS_COUNT=$(printf '%s\n' "$NO_LIMITS" | grep -c . || true)
  echo -e "${RED}❌ Found pods without resource limits (${NO_LIMITS_COUNT}):${NC}"
  NO_LIMITS_SAMPLES=$(printf '%s\n' "$NO_LIMITS" | head -n 5)
  echo "$NO_LIMITS_SAMPLES"
  if [[ "$NO_LIMITS_COUNT" -gt 5 ]]; then echo "...and more"; fi
fi

echo -e "\n${YELLOW}[4/4] Checking for Workloads in 'default' Namespace...${NC}"
DEFAULT_PODS=$(kubectl get pods -n default -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
if [[ -z "$DEFAULT_PODS" ]]; then
  echo -e "${GREEN}✅ No workloads found in 'default' namespace.${NC}"
else
  DEFAULT_COUNT=$(printf '%s\n' "$DEFAULT_PODS" | grep -c . || true)
  echo -e "${RED}❌ Found workloads in 'default' namespace (${DEFAULT_COUNT}):${NC}"
  DEFAULT_SAMPLES=$(printf '%s\n' "$DEFAULT_PODS" | head -n 5)
  echo "$DEFAULT_SAMPLES"
  if [[ "$DEFAULT_COUNT" -gt 5 ]]; then echo "...and more"; fi
fi

TOTAL=$((PRIVILEGED_COUNT + ROOT_COUNT + NO_LIMITS_COUNT + DEFAULT_COUNT))
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
CONTEXT="$(kubectl config current-context 2>/dev/null || echo unknown)"

write_md() {
  local dest="$1"
  {
    echo "# Kube-Simple-Audit Report"
    echo ""
    echo "| Field | Value |"
    echo "|-------|-------|"
    echo "| Generated (UTC) | ${TIMESTAMP} |"
    echo "| kubectl context | \`${CONTEXT}\` |"
    echo "| Total flagged items | **${TOTAL}** |"
    echo ""
    echo "## Summary"
    echo ""
    echo "| Check | Count | Status |"
    echo "|-------|------:|--------|"
    echo "| Privileged pods | ${PRIVILEGED_COUNT} | $([[ $PRIVILEGED_COUNT -eq 0 ]] && echo PASS || echo FAIL) |"
    echo "| Missing runAsNonRoot | ${ROOT_COUNT} | $([[ $ROOT_COUNT -eq 0 ]] && echo PASS || echo FAIL) |"
    echo "| Missing resource limits | ${NO_LIMITS_COUNT} | $([[ $NO_LIMITS_COUNT -eq 0 ]] && echo PASS || echo FAIL) |"
    echo "| Workloads in default ns | ${DEFAULT_COUNT} | $([[ $DEFAULT_COUNT -eq 0 ]] && echo PASS || echo FAIL) |"
    echo ""
    echo "## Findings (samples)"
    echo ""
    echo "### Privileged pods"
    if [[ -n "$PRIVILEGED_SAMPLES" ]]; then echo '```'; echo "$PRIVILEGED_SAMPLES"; echo '```'; else echo "_None_"; fi
    echo ""
    echo "### Potential root containers"
    if [[ -n "$ROOT_SAMPLES" ]]; then echo '```'; echo "$ROOT_SAMPLES"; echo '```'; else echo "_None_"; fi
    echo ""
    echo "### Missing resource limits"
    if [[ -n "$NO_LIMITS_SAMPLES" ]]; then echo '```'; echo "$NO_LIMITS_SAMPLES"; echo '```'; else echo "_None_"; fi
    echo ""
    echo "### Default namespace workloads"
    if [[ -n "$DEFAULT_SAMPLES" ]]; then echo '```'; echo "$DEFAULT_SAMPLES"; echo '```'; else echo "_None_"; fi
    echo ""
    echo "## What to do next"
    echo ""
    echo "1. Fix CRITICAL-looking items first (privileged / host namespaces)."
    echo "2. Add \`runAsNonRoot\` + resource limits in your Deployment templates."
    echo "3. Move workloads out of \`default\` into dedicated namespaces."
    echo "4. Wire manifest CI with [k8s-security-gate](https://github.com/ranas-mukminov/k8s-security-gate) before deploy."
    echo "5. Bootstrap a secure baseline with the [Secure K3s GitOps Template](${STARTER_URL})."
    echo ""
    echo "## Commercial follow-up"
    echo ""
    echo "Need a deeper review or a day-to-prod hardening pack?"
    echo ""
    echo "- **Express Audit + Hardening:** [${CTA_URL}](${CTA_URL})"
    echo "- **Secure K3s Starter (OSS → commercial pack):** [${STARTER_URL}](${STARTER_URL})"
    echo "- Telegram: [@run_as_daemon_dev](https://t.me/run_as_daemon_dev)"
    echo ""
  } > "$dest"
}

if [[ -n "$MD_OUT" ]]; then
  write_md "$MD_OUT"
  echo -e "\n${GREEN}Markdown report written to ${MD_OUT}${NC}"
fi

if [[ -n "$WRITE_SUMMARY" ]]; then
  TMP_MD="$(mktemp)"
  write_md "$TMP_MD"
  cat "$TMP_MD" >> "$WRITE_SUMMARY"
  rm -f "$TMP_MD"
fi

echo -e "\n"
echo -e "${BLUE}################################################################${NC}"
echo -e "${BLUE}#                   Audit Complete                             #${NC}"
echo -e "${BLUE}################################################################${NC}"
echo -e "${YELLOW}Detected potential risks?${NC}"
echo -e "${YELLOW}Book a professional Deep-Dive Architecture Audit:${NC}"
echo -e "${GREEN}${CTA_URL}${NC}"
echo -e "${YELLOW}Or start from the Secure K3s Starter template:${NC}"
echo -e "${GREEN}${STARTER_URL}${NC}"
echo -e "${BLUE}################################################################${NC}"
echo -e "\n"
