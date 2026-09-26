# Kube-Simple-Audit ☸️

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-blue.svg)](https://www.gnu.org/software/bash/)

> 5-second security sanity check for K8s clusters. Zero dependencies beyond `kubectl` + `jq`.

**Kube-Simple-Audit** is a lightweight Bash lead-magnet for the Secure K3s Starter hub. It flags common misconfigurations and writes a **Markdown report** you can paste into tickets or GitHub Step Summary.

[https://run-as-daemon.dev](https://run-as-daemon.dev) | [GitHub @ranas-mukminov](https://github.com/ranas-mukminov) | [Secure-K3s-GitOps-Template](https://github.com/ranas-mukminov/Secure-K3s-GitOps-Template)

---

## One-liner

Requires a working `kubectl` context and `jq`:

```bash
curl -fsSL https://raw.githubusercontent.com/ranas-mukminov/Kube-Simple-Audit/main/audit.sh | bash
```

Markdown report:

```bash
curl -fsSL https://raw.githubusercontent.com/ranas-mukminov/Kube-Simple-Audit/main/audit.sh | bash -s -- --markdown
# → kube-simple-audit-report.md
```

Or clone:

```bash
git clone https://github.com/ranas-mukminov/Kube-Simple-Audit.git
cd Kube-Simple-Audit
./audit.sh --markdown -o report.md
```

## Checks

| # | Check | Why it matters |
|---|--------|----------------|
| 1 | Privileged pods | Near-root on the node |
| 2 | Missing `runAsNonRoot` | Containers may run as UID 0 |
| 3 | Missing resource limits | Noisy-neighbor / DoS risk |
| 4 | Workloads in `default` | Weak tenancy / RBAC hygiene |

## Markdown report + Actions summary

- `--markdown` / `-o FILE` writes a structured MD report (summary table, samples, next steps, CTA).
- When `GITHUB_STEP_SUMMARY` is set (GitHub Actions), the same report is appended automatically — **no secrets required** beyond the runner's kubeconfig / your local kubeconfig.

Example job (copy into *your* workflow; needs cluster credentials you already manage):

```yaml
# examples only — do not enable without a kubeconfig secret you control
- name: Kube Simple Audit
  env:
    KUBECONFIG: ${{ secrets.KUBECONFIG }}
  run: |
    curl -fsSL https://raw.githubusercontent.com/ranas-mukminov/Kube-Simple-Audit/main/audit.sh | bash -s -- --markdown
    cat kube-simple-audit-report.md >> "$GITHUB_STEP_SUMMARY"
```

## What to do with results

1. Fix privileged / hostNetwork-style issues first.
2. Codify `runAsNonRoot` + limits in Deployment templates.
3. Add manifest CI via [k8s-security-gate](https://github.com/ranas-mukminov/k8s-security-gate) (fail on CRITICAL/HIGH).
4. Bootstrap a Zero Trust baseline with [Secure-K3s-GitOps-Template](https://github.com/ranas-mukminov/Secure-K3s-GitOps-Template).

## Commercial follow-up

Need a deeper analysis or a guided Starter pack?

- **[Express Audit + Hardening](https://run-as-daemon.dev/en/services/express-audit-hardening.html)**
- Telegram: [@run_as_daemon_dev](https://t.me/run_as_daemon_dev)

## Privacy

Runs entirely with your local `kubectl`. No data leaves your machine unless you upload the report yourself.

## License

MIT — see [LICENSE](LICENSE).
