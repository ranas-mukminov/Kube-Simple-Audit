# Kube-Simple-Audit ☸️

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-blue.svg)](https://www.gnu.org/software/bash/)

> 5-second security sanity check for K8s clusters. Zero dependencies.

**Kube-Simple-Audit** is a lightweight Bash script designed to perform a quick "sanity check" on any Kubernetes cluster using only `kubectl` and `jq`. It identifies common security misconfigurations and potential risks in seconds.

[https://run-as-daemon.dev](https://run-as-daemon.dev) | [GitHub @ranas-mukminov](https://github.com/ranas-mukminov)

---

## Features

- **Privileged Pods Detection**: Identifies pods running with `securityContext.privileged: true`.
- **Root Container Check**: Warns about pods running as root (UID 0) or missing `runAsNonRoot`.
- **Resource Limits Audit**: Flags pods without CPU/Memory limits set.
- **Default Namespace Check**: Alerts if workloads are deployed in the `default` namespace.
- **Zero Dependencies**: Requires only `kubectl` and `jq`.
- **Color-Coded Output**: Easy-to-read Red ❌ / Green ✅ results.

## Quick Start

Run the audit on your cluster immediately:

```bash
git clone https://github.com/ranas-mukminov/Kube-Simple-Audit.git
cd Kube-Simple-Audit
chmod +x audit.sh
./audit.sh
```

## Usage

Ensure you have `kubectl` configured with access to your cluster and `jq` installed.

```bash
./audit.sh
```

The script will iterate through all namespaces and report findings.

## Commercial Support

Need a deeper analysis? **Ranas Security** offers professional services to secure your infrastructure:

- **Deep-Dive Architecture Audit**: Comprehensive security assessment.
- **Infrastructure Hardening**: Implementation of CIS Benchmarks and best practices.
- **DevSecOps Implementation**: Integrating security into your CI/CD pipelines.

👉 **[Book a professional Deep-Dive Architecture Audit](https://run-as-daemon.dev/en/services/express-audit-hardening.html)**

## Privacy & Compliance

This tool runs entirely locally on your machine.
- **No data collection**: It does not send any data to external servers.
- **No secrets logging**: It only reads pod metadata (names, namespaces, security contexts).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
