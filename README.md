# OTel Agent & Gateway Health dashboard

Deploy from repository root after copying `observability/grafana/dashboards/collector-health/` into your repository:

```bash
kubectl apply -k observability/grafana/dashboards/collector-health
```

Uses Grafana Prometheus datasource UID `prometheus`. Existing Fedora host dashboard is unaffected. This package does not change Collector/Kubernetes deployments.

The first ten monitoring panels use metrics explicitly observed in the supplied query output. Exporter panels use common names that must be verified in your environment; if they show No data, inspect `count by (__name__) ({__name__=~"otelcol_exporter_.*"})`. The topology is configured/documented, not automatically discovered.


v1.1: Confirmed exporter metrics. Replaced unobserved send-failure metric with exporter queue utilization; added in-flight requests and Mimir remote-write batches/sec. Verify labels and scrape status in Prometheus. Missing failures cannot be interpreted as zero failures.
