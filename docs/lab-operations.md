# Operations, validation and known limitations

## Daily operation

Use kubectl config current-context before changes. For local access use kubectl port-forward; do not bind unauthenticated services to public interfaces. Grafana typically uses service port 80 or 3000 depending on chart; inspect kubectl -n observability get svc and forward the actual service port to local 3000. Headlamp and FleetAMP are optional. The original lab used a localhost:19090 Python/systemd control dashboard, not yet packaged in this repository. It managed demo replica counts and local port-forwards; cloud destination switches were proposed but not implemented.

Stop Locust first:
```sh
kubectl -n otel-demo scale deployment/load-generator --replicas=0
```
For a dedicated demo namespace, record deployment replica counts before scaling application deployments to zero. Do not scale unrelated workloads. Restore the recorded counts when starting, then start load-generator only after the application is ready. Scaling does not preserve ephemeral data. Background telemetry may continue even with Locust stopped. To remove the demo, helm uninstall otel-demo -n otel-demo; inspect PVCs before deleting them or the namespace.

## Health and troubleshooting

- Check kubectl get nodes, kubectl -n observability get pods,pvc, kubectl -n otel-demo get pods and kubectl describe pod for failures.
- Check gateway logs and internal metrics (port-forward its metrics service port, usually 8888). Inspect exporter sent, failed and queue metrics; names vary by Collector version. Shared exporters aggregate multiple workloads.
- Grafana dashboard provisioning sidecar previously wrote dashboard files but reload returned HTTP 401. Check provisioning credentials and file reload; do not reset credentials blindly.
- The original lightweight FastAPI demo was in demo-apps with deployment otel-observability-demo and CronJob otel-demo-traffic. Suspend the CronJob and scale the deployment to zero before removing it. Delete the namespace only after confirming it contains no other resources or important data. Source repository should be retained. Removal was instructed, not independently verified.
- On Fedora, intermittent Wi-Fi/ARP connectivity between laptops was investigated; disabling Wi-Fi power saving coincided with recovery, but root cause was not proven. Prefer wired networking and stable IPs for kubeadm.
- Golden Kubernetes Application Health dashboard used local Prometheus metrics and was provisioned in the lab; its source lives in the separate demo repository pending consolidation. Not all panels were independently validated.

## Grafana Cloud Application Observability: deferred

Traces were visible in Grafana Cloud Explore, but application services were not visible in Application Observability. OTLP forwarding alone does not guarantee application inventory, RED metrics or service graph configuration. Investigate compatible span-derived metrics and service graph generation, data sources and service identity. The demo already generates span metrics; the cloud allowlist may exclude required metadata.

Knowledge Graph activation returned HTTP 409. Exact conflict remains unknown. Kubernetes sanity checks reported missing kube_pod_info, kube_pod_owner, kube_pod_status_phase, kube_replicaset_owner, kube_node_info with cluster/node/internal_ip labels (or alternate kubelet_node_name mapping), and kube_node_status_allocatable. These are collected locally by Prometheus but not intentionally forwarded to cloud. Application-only activation is worth investigating if supported; do not assume Kubernetes blockers caused the 409.

Cloud estimated at least 4,050 additional active series (~104.4% of existing usage). Approximate total 7,929 series, before additional Kubernetes metrics. Verify actual subscription limits and host-hour charges; no guarantee of free operation. Keep Knowledge Graph deferred until cost and provisioning are understood. Selective remote write of discovery metrics with consistent cluster labels is a possible future approach, not implemented.

Diagnostic PromQL: traces_target_info, traces_spanmetrics_calls_total, traces_service_graph_request_total, and count by (__name__) ({__name__=~"traces_.*"}). Names depend on generation source. Capture actual failed build response without cookies/tokens.

## FleetAMP and future work

FleetAMP v0.3.0 development build and a test OpAMP Supervisor/Collector were deployed in the original lab, with persistent identity and local PVCs. The test agent connected successfully; production TLS, authorization, remote configuration acceptance, drift and rollback tests remain separate work. See https://github.com/marellasunil/FleetAMP for project documentation. Do not copy the original lab's insecure HTTP/WS settings into production. FleetAMP is optional, not a prerequisite for telemetry.

Pending: portable Helm values and installation scripts validated across all three cluster types, dashboard consolidation, independent cloud export controls, incident simulations, GenAI observability, tenant isolation and GitOps. Keep local-only defaults and never commit kubeconfigs, credentials, raw live ConfigMaps or secret-bearing rendered manifests.
