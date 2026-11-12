# Reproduce the observability lab

Status: reference instructions, not a fully automated installer. The Fedora kubeadm lab and three-backend application ingestion were exercised; Kind and single-node installation paths need independent end-to-end testing. Use a disposable lab, not production.

## 1. Choose a cluster

Install kubectl, Helm 3, Git, curl and Python 3 with PyYAML. Use supported matching Kubernetes versions. A full Astronomy Shop plus the observability stack needs substantial RAM: our 16 GiB worker ran the workloads, but resource requirements vary. Prefer 16 GiB or more available to the cluster, 8 CPU threads and ample disk; start with the core stack on smaller systems. Check actual requests, usage and disk before adding the demo.

### Kind (Docker or compatible supported provider)

Install Kind from https://kind.sigs.k8s.io/docs/user/quick-start/ and start your container runtime.

```sh
kind create cluster --name observability-lab
kubectl config use-context kind-observability-lab
kubectl get nodes
kubectl get storageclass
```

Kind normally provides a local-path storage class. Use port-forwarding, not host-specific NodePorts. For a multi-node Kind cluster, see the Kind configuration documentation. Allocate enough memory to the container runtime.

### Single-node kubeadm

Follow https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/ and https://kubernetes.io/docs/setup/production-environment/container-runtimes/ for your OS. Configure containerd CRI with systemd cgroups, enable IP forwarding and required kernel modules, and disable swap unless explicitly configuring Kubernetes swap support. Do not blindly disable SELinux or the firewall.

Choose a stable reachable node IP and a non-overlapping pod CIDR. Example (choose a CNI compatible with this CIDR):

```sh
sudo kubeadm init --apiserver-advertise-address=<NODE_IP> --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///run/containerd/containerd.sock
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
```

The angle-bracket placeholder must be replaced before execution. Back up any existing kubeconfig instead of overwriting it. Install a compatible CNI following its official instructions (e.g. Calico with matching IP pool). Wait for the node to be Ready. For a disposable single-node lab only:

```sh
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl get nodes
```

Install a local storage provisioner following its documentation (e.g. https://github.com/rancher/local-path-provisioner). Verify a default StorageClass and test a PVC. Local storage is node-bound, not HA.

### Multi-node kubeadm

Prepare each machine as above. Initialize only the control plane, install the CNI once, and run the join command on each worker:

```sh
# On control plane:
sudo kubeadm token create --print-join-command
# On worker: run the printed sudo kubeadm join command
# On control plane:
kubectl get nodes -o wide
```

Keep control-plane taint unless intentionally scheduling there. Use stable LAN addresses, firewall rules scoped to cluster nodes and CNI requirements, and reliable networking. Kubernetes API port 6443 must be reachable from the administration machine; kubelet and CNI ports depend on the setup. Do not publish the API or lab services to the internet. Copy kubeconfig securely to an administration laptop if needed; its server address must be reachable. Never commit kubeconfig or join tokens. The original lab used Fedora, containerd and kubeadm, with a separate administration laptop; a true multi-node control-plane/worker topology is an additional deployment option, not a claim that this exact topology was tested.

## 2. Preflight and common platform

```sh
kubectl config current-context
kubectl get nodes -o wide
kubectl get storageclass
kubectl get pods -A
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
```

Inspect repository manifests and existing install scripts before applying. Use one Prometheus stack (kube-prometheus-stack), Grafana, Mimir, Loki, Tempo and optionally Pyroscope. Use single-binary lab modes and persistent volumes where supported; configure retention and resource requests. Install in dependency order: storage, Prometheus and backends, Grafana data sources, OTel gateway, then demo. Pin chart versions and use helm show values to check version-specific settings. Do not install duplicate Grafana/Prometheus instances if already provided by a chart. Use ClusterIP services and internal DNS; configure Grafana data sources for Prometheus, Mimir, Loki and Tempo. Prometheus datasource UID prometheus is required by the existing collector-health dashboard.

See [Grafana Helm charts](https://github.com/grafana/helm-charts), [Prometheus community charts](https://github.com/prometheus-community/helm-charts) and [OpenTelemetry Helm charts](https://github.com/open-telemetry/opentelemetry-helm-charts). Exact backend values and automated install commands must be reconciled with the live lab before this is a turnkey installer.

Verify each release with helm list -A, kubectl get pods -n observability, kubectl get pvc -n observability. Check Prometheus targets and query kube_pod_info. Install the existing dashboard using the command in the root README.

## 3. Application and optional integrations

Follow [Astronomy Shop and cloud exports](astronomy-shop-cloud.md). Keep cloud exports disabled by default. See [operations and findings](lab-operations.md).

## 4. Validation

Check node readiness, PVC binding, pod readiness, gateway logs and exporter counters. Generate one user of demo traffic and verify metrics in Mimir, logs in Loki and traces in Tempo. Verify each enabled cloud destination separately. Stop load and workloads when finished. Record chart/image versions, cluster type and actual resource usage in your test notes.
