# Portable installation

The reference catalog pins the live Helm versions and uses Kustomize for Mimir and the gateway. The default profile installs the local stack and Astronomy Shop. Cloud integrations, FleetAMP and Headlamp are not automated yet.

Run from the repository root with Python 3.9+, PyYAML, Bash, kubectl and Helm. Follow [foundation setup](lab-foundation.md), then:

```sh
cp examples/lab-config.example.yaml lab-config.yaml
cp examples/releases.example.yaml releases.yaml
python3 scripts/install.py
```

Set the exact context and storage class first. The installer rewrites explicit storageClass/storageClassName fields in temporary Helm values and the Mimir PVC; components without explicit settings use the cluster default. Use a default provisioner matching the selected class. Kind normally uses standard; kubeadm reference uses local-path. The plan renders Kustomize locally and prints commands; temporary paths are not reusable. No cluster mutation occurs in plan mode.

On a fresh disposable cluster, after review, run `python3 scripts/install.py --apply`. The installer checks dependencies, preflight, existing resources, renders Helm charts and installs in order. Existing resources require explicit --allow-upgrade; do not use it on the reference lab without reviewing changes. A failure leaves earlier releases installed. No automatic rollback. Prometheus is required for ServiceMonitor CRDs. Grafana and gateway require all local backends; demo requires gateway. Only the reference load settings (one user, manual start) are supported. Cloud switches are rejected. Disabled components are not uninstalled.

The demo uses the captured chart 0.42.6 values, dedicated gateway ports 14317/14318 and local-only exports. Grafana provisions four data sources. The Tempo-to-Loki query targets otel-demo and still requires verification against actual log labels and bodies. Pyroscope datasource, host agent, dashboards and NodePort can be installed separately; they are not automated by this script.

Validate actual metrics, logs and traces after installation. See [demo guide](astronomy-shop-cloud.md). This is a lab, not a production architecture. Clean-cluster end-to-end testing remains pending.

## Optional components

After core installation, review and apply `kubectl --context YOUR_CONTEXT apply -k observability/otel/agent` for host metrics (read-only host mounts, root container, all eligible nodes). On Kind these describe container nodes, not the physical host. Apply `kubectl --context YOUR_CONTEXT apply -k observability/grafana/dashboards` for dashboard provisioning. Grafana sidecar reload may require valid credentials or a restart. For Headlamp use the pinned chart: `helm --kube-context YOUR_CONTEXT repo add headlamp https://kubernetes-sigs.github.io/headlamp/` then `helm --kube-context YOUR_CONTEXT upgrade --install headlamp headlamp/headlamp --version 0.46.0 -n headlamp --create-namespace --wait`. Use least-privilege Kubernetes authentication and loopback port forwarding; do not expose admin tokens. See [cloud exports](../integrations/cloud/README.md), [FleetAMP](../integrations/fleetamp/README.md) and [lab controls](../tools/lab-control/README.md). These optional steps are manual, not integrated into install.py.
