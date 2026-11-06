# Tested Lab Versions

Baseline: 2026-11-06

| Component | Version |
|---|---|
| Fedora | 45 Workstation |
| Kubernetes | v1.36.6 |
| containerd | 2.4.2 |
| Grafana Helm chart | 14.4.0 |
| Grafana application | 13.3.0 |
| kube-prometheus-stack Helm chart | 92.21.2 |
| Prometheus Operator | v0.94.2 |

## Environment

- Single-node kubeadm Kubernetes cluster
- Container runtime: containerd
- Namespace: observability
- StorageClass: local-path
- Grafana service: ClusterIP, with a separate NodePort service
- Grafana NodePort: 30080

## Portability

The current Grafana root_url contains the hostname
fedora-worker. Replace or parameterize it when
deploying on another machine.

This version baseline does not yet pin Calico,
Local Path Provisioner, or Metrics Server.
