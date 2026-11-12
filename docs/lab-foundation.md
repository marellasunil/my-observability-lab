# Executable foundation

These commands are the first portable implementation, not a complete observability installer. Run from the repository root with Bash, Python 3, PyYAML, kubectl and Helm installed. Kind bootstrap additionally requires Kind and a supported running container provider.

```sh
cp examples/lab-config.example.yaml lab-config.yaml
```

For an existing single-node or multi-node cluster, set cluster.type to existing, cluster.context to the exact kubeconfig context, and storage.className to an existing provisioner. For Kind set cluster.type to kind, cluster.name to observability-lab, cluster.context to kind-observability-lab and storage.className to standard (check the actual provisioner after creation).

```sh
# Kind only; creates a cluster if absent.
bash scripts/lab-foundation.sh bootstrap-kind lab-config.yaml
# All cluster types:
bash scripts/lab-foundation.sh preflight lab-config.yaml
```

The script explicitly scopes kubectl and Helm commands to the configured context. Kind itself may update the current kubeconfig context during creation. Existing cluster bootstrap is intentionally manual; see [cluster guide](lab-reproduction.md).

After deploying the core stack following the reference guide:

```sh
bash scripts/lab-foundation.sh inventory lab-config.yaml
bash scripts/lab-foundation.sh verify lab-config.yaml
```

Inventory reports resource metadata, not credentials or raw configuration. Verification checks API/node readiness, storage class existence, gateway rollout and frontend rollout if the demo namespace exists. It does not verify all components, PVC provisioning, telemetry delivery or resource capacity. Inspect listed pods/PVCs and query each backend as described in [demo guide](astronomy-shop-cloud.md).

Only cluster and storage fields are consumed by this initial script. Core component toggles are consumed by the separate [portable installer](portable-installation.md). Cloud integration and load/sampling settings remain reserved; the foundation script itself does not deploy or reconfigure anything. No cloud export is enabled by these commands.

The scripts have not yet been run on a live cluster. Exact sanitized Helm values, install orchestration, dashboard packaging and clean-cluster tests remain pending. Do not use the lab as production infrastructure.
