# Portable core installer

This is an initial Helm orchestration implementation, not a validated full-stack distribution. It deliberately refuses to install until exact chart versions and reviewed values files are provided. The example catalog is a proposed chart mapping, not an inventory of the running lab. In particular, Mimir distributed chart must be configured for appropriate lab resource usage, and the existing gateway may use raw manifests rather than Helm.

## Prepare

From the repository root, install Python 3.9+, PyYAML, Bash, Helm and kubectl. Complete the [foundation guide](lab-foundation.md).

```sh
cp examples/releases.example.yaml releases.yaml
cp examples/lab-config.example.yaml lab-config.yaml
```

Edit cluster context and storage class in lab-config.yaml. Review each enabled core component in releases.yaml. Supply an exact chart version and a reviewed repository-relative values file. Disable the Grafana dependency in kube-prometheus-stack if deploying standalone Grafana. Configure storage classes, resource limits, retention, backend endpoints and Grafana data sources in the actual chart values; the installer does not translate the storage setting into chart-specific values. Use a local-only gateway config and verify it contains no cloud destinations. Never include credentials in values or commit raw live values.

## Plan and apply

```sh
python3 scripts/install.py --config lab-config.yaml --releases releases.yaml
```

The default mode prints the plan and performs no mutations. Missing versions or files cause a nonzero exit. Once the plan is complete and reviewed:

```sh
python3 scripts/install.py --config lab-config.yaml --releases releases.yaml --apply
```

Apply runs preflight, refuses existing release names unless --allow-upgrade is explicitly passed, adds Helm repositories, renders all selected charts, then installs sequentially with readiness waits. Helm template is not server-side validation. A failed install stops subsequent releases; earlier releases remain installed. Review helm status and history before retrying. No automatic deletion or rollback is performed. Use a fresh disposable cluster for initial testing; do not run against the working lab.

Component switches are now consumed for the seven core Helm releases. Astronomy Shop, FleetAMP and Headlamp remain deferred and are reported, not installed. Cloud integration switches are rejected if enabled. Values files must themselves be local-only; the installer cannot guarantee their contents. It does not install a CNI or storage provisioner, generate credentials, configure chart-specific storage, or verify ingestion.

## Reconcile with the reference lab

When the administration laptop is available, run foundation inventory and inspect Helm release metadata. Retrieve actual values locally with restrictive file permissions; never commit raw values or rendered manifests. Compare each release and chart version with the catalog, replace proposed mappings as needed, and construct sanitized portable values. Check existing raw manifests separately. Test on Kind, then single-node and multi-node kubeadm. Document actual resource use and validate each signal end to end.

The current installer has not been exercised against a live Kubernetes cluster. Exact portable values and complete demo packaging are still required before a one-command installation can be advertised.
