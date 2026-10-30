#!/usr/bin/env bash
# Safe offline regression tests. No Kubernetes cluster or network access required.
set -euxo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

cat > "$TMP/bin/kubectl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  "get pods --all-namespaces -o json")
    if [[ "${FAKE_KUBECTL_FAIL:-0}" == 1 ]]; then
      echo "simulated access denied" >&2
      exit 13
    fi
    cat "${FAKE_PODS_FILE:?}"
    ;;
  "config current-context")
    printf '%s\n' "offline-test-context"
    ;;
  *)
    echo "unexpected kubectl arguments: $*" >&2
    exit 2
    ;;
esac
MOCK
chmod +x "$TMP/bin/kubectl"

cat > "$TMP/pods.json" <<'JSON'
{
  "items": [
    {
      "metadata": {"name": "privileged", "namespace": "team"},
      "spec": {
        "securityContext": {"runAsNonRoot": true},
        "containers": [
          {"name": "app", "securityContext": {"runAsNonRoot": true, "privileged": true},
           "resources": {"limits": {"cpu": "100m"}}}
        ]
      }
    },
    {
      "metadata": {"name": "root", "namespace": "team"},
      "spec": {
        "containers": [
          {"name": "app", "resources": {"limits": {"cpu": "100m"}}}
        ]
      }
    },
    {
      "metadata": {"name": "no-limits", "namespace": "default"},
      "spec": {
        "securityContext": {"runAsNonRoot": true},
        "containers": [
          {"name": "app", "securityContext": {"runAsNonRoot": true}, "resources": {}}
        ]
      }
    }
  ]
}
JSON

export PATH="$TMP/bin:$PATH"
export FAKE_PODS_FILE="$TMP/pods.json"

bash "$REPO_ROOT/audit.sh" --markdown -o "$TMP/report.md" > "$TMP/audit.stdout"

grep -Fq 'Found privileged pods (1)' "$TMP/audit.stdout"
grep -Fq 'Found pods potentially running as root (1)' "$TMP/audit.stdout"
grep -Fq 'Found pods without resource limits (1)' "$TMP/audit.stdout"
grep -Fq "Found workloads in 'default' namespace (1)" "$TMP/audit.stdout"

grep -Fq '| Privileged pods | 1 | FAIL |' "$TMP/report.md"
grep -Fq '| Missing runAsNonRoot | 1 | FAIL |' "$TMP/report.md"
grep -Fq '| Missing resource limits | 1 | FAIL |' "$TMP/report.md"
grep -Fq '| Workloads in default ns | 1 | FAIL |' "$TMP/report.md"
grep -Fq 'offline-test-context' "$TMP/report.md"

# Clean fixture: no findings, no external services required.
jq '.items = [.items[0]] | .items[0].spec.containers[0].securityContext.privileged = false' \
  "$TMP/pods.json" > "$TMP/clean.json"
FAKE_PODS_FILE="$TMP/clean.json" bash "$REPO_ROOT/audit.sh" --markdown -o "$TMP/clean-report.md" > "$TMP/clean.stdout"

grep -Fq '| Privileged pods | 0 | PASS |' "$TMP/clean-report.md"
grep -Fq '| Missing runAsNonRoot | 0 | PASS |' "$TMP/clean-report.md"
grep -Fq '| Missing resource limits | 0 | PASS |' "$TMP/clean-report.md"
grep -Fq '| Workloads in default ns | 0 | PASS |' "$TMP/clean-report.md"

# Fail closed: unauthorized kubectl must never produce a misleading clean report.
if FAKE_KUBECTL_FAIL=1 bash "$REPO_ROOT/audit.sh" > "$TMP/failure.stdout" 2>&1; then
  echo 'ERROR: audit succeeded even when kubectl failed' >&2
  exit 1
fi
grep -Fq 'Aborting instead of reporting a clean result.' "$TMP/failure.stdout"

echo 'OK: risky fixture, clean fixture, and permission-denied paths'
