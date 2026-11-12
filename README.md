# My Observability Lab

A local-first Kubernetes observability reference lab using OpenTelemetry, Grafana OSS and optional cloud destinations. Learn application instrumentation, telemetry routing, Kubernetes monitoring and operational troubleshooting with Astronomy Shop.

## Getting started

Choose Kind, single-node kubeadm or multi-node kubeadm in the [reproduction guide](docs/lab-reproduction.md). Then follow [Astronomy Shop and cloud integrations](docs/astronomy-shop-cloud.md) and [operations and known limitations](docs/lab-operations.md).

Default target architecture: application SDKs → demo Collector → central OTel gateway → Mimir, Loki and Tempo → Grafana. Prometheus monitors Kubernetes and Collector health. Optional Grafana Cloud and Splunk Observability Cloud exports, Pyroscope and FleetAMP management.

**Status:** documentation of the working lab and reference recipes. The Fedora lab and three-destination ingestion were exercised; Kind and single-node/multi-node portable installation recipes are not yet independently validated. Complete sanitized Helm values and automated installation remain pending. Cloud integrations are optional and may incur charges. Never commit credentials.

## Executable foundation

Copy `examples/lab-config.example.yaml` to `lab-config.yaml`, configure the cluster context and storage class, then run `bash scripts/lab-foundation.sh preflight lab-config.yaml`. For Kind creation, inventory and verification commands, see [executable foundation](docs/lab-foundation.md). The foundation script does not install the observability stack; use the separate core installer below.

## Portable core installer

See [portable installation](docs/portable-installation.md) for the new plan-first Helm orchestration script. Exact chart versions and reviewed values are required before applying. The core component switches are consumed by this installer; optional integrations and demo packaging remain pending.

## Existing dashboard package

### OTel Agent & Gateway Health dashboard

Deploy from repository root after copying `observability/grafana/dashboards/collector-health/` into your repository:

```bash
kubectl apply -k observability/grafana/dashboards/collector-health
```

Uses Grafana Prometheus datasource UID `prometheus`. Existing Fedora host dashboard is unaffected. This package does not change Collector/Kubernetes deployments.

The first ten monitoring panels use metrics explicitly observed in the supplied query output. Exporter panels use common names that must be verified in your environment; if they show No data, inspect `count by (__name__) ({__name__=~"otelcol_exporter_.*"})`. The topology is configured/documented, not automatically discovered.


v1.1: Confirmed exporter metrics. Replaced unobserved send-failure metric with exporter queue utilization; added in-flight requests and Mimir remote-write batches/sec. Verify labels and scrape status in Prometheus. Missing failures cannot be interpreted as zero failures.
