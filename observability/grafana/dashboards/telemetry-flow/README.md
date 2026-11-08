# Telemetry Flow & Pipeline Health

Prometheus datasource UID: `prometheus`. Designed for the existing OTel Agent/Gateway lab and Grafana sidecar ConfigMap discovery.

Deploy from repo root after copying this directory to `observability/grafana/dashboards/telemetry-flow`:

```bash
kubectl apply --dry-run=server -k observability/grafana/dashboards/telemetry-flow
kubectl apply -k observability/grafana/dashboards/telemetry-flow
```

This dashboard shows **configured** topology, not automatically discovered or verified end-to-end delivery. The Prometheus path is a pull scrape of Gateway :8889; Mimir uses remote write. Check that `up{job="otel-gateway",endpoint="prometheus"}` matches your actual scrape labels. A healthy exporter counter does not guarantee backend ingestion.

If deploying from a parent `dashboards/kustomization.yaml`, add this folder to its `resources` rather than applying separately.
