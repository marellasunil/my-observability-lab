# Installation plan

This bundle is for **fresh Fedora 45 single-node kubeadm lab installs**. It is not an in-place repair/upgrade system. Run host-level installers on the **future new Kubernetes node**, not the management laptop. Run kubectl/Helm scripts from a host with valid kubeconfig (Latitude is fine).

1. Review `config/lab.env.example`, copy to `config/lab.env` and change IP, interface, and LAN CIDR. Never put credentials in Git.
2. Run `./scripts/bootstrap-fedora.sh --dry-run` and `./scripts/install-containerd.sh --dry-run`.
3. On a **fresh node only**, after reviewing outputs: `sudo ./scripts/bootstrap-fedora.sh --apply`, `sudo ./scripts/install-containerd.sh --apply`, `sudo ./scripts/install-kubernetes.sh --apply`.
4. Disable swap **manually and persistently** after reviewing your Fedora swap/zram setup. Do not edit fstab blindly.
5. On a fresh node only: `sudo ./scripts/initialize-cluster.sh --dry-run`, then `sudo ./scripts/initialize-cluster.sh --apply`. Back up the generated kubeconfig securely; do not commit it.
6. Configure kubectl credentials and (for a single node) remove the control-plane taint only if you want workloads on that node: `kubectl taint nodes --all node-role.kubernetes.io/control-plane-`.
7. Run `install-networking.sh`, `install-storage.sh`, `install-metrics-server.sh` in dry-run first, then apply individually. Wait for Ready nodes/pods and Bound PVCs before proceeding.
8. Copy **your tested existing** Grafana and Prometheus values and NodePort manifest into `observability/` before running `install-monitoring.sh`. Check `helm diff`/rendered manifests before applying an upgrade to an existing release.
9. Run `validate-cluster.sh`.

## Caveats

- `--dry-run` is a planning/check mode, not a simulation of all package and Kubernetes changes.
- Kubernetes repo/package availability and Helm/Calico/metrics-server chart or manifest compatibility must be verified on the intended installation day.
- Calico operator chart availability at the pinned version is checked only during `--apply`; inspect the current Calico CRD schema before rollout.
- Metrics Server defaults to validating kubelet certificates. The existing lab needed `--kubelet-insecure-tls`; this is a lab-only workaround and is intentionally not enabled automatically.
- Storage is node-local. Deleting the node or PVC may permanently lose Grafana/Prometheus data. Git stores configuration, **not** telemetry data or PVC backups.
- For security, check Fedora firewalld broad port allowances (see `docs/firewall.md`).
- `install-monitoring.sh --apply` uses Helm upgrades: review values, backups and changes first, especially on an existing cluster.
