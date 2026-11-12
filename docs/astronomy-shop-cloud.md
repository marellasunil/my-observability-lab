# Astronomy Shop and optional cloud destinations

The lab uses the official OpenTelemetry Demo (Astronomy Shop), chart 0.42.6 and application 3.1.0 in the tested setup. Gateway image: otel/opentelemetry-collector-contrib:0.164.0. Versions are historical lab pins, not a recommendation to ignore security updates.

## Local-first architecture

Application SDKs -> demo Collector -> central gateway -> Mimir (metrics), Loki (logs), Tempo (traces). Prometheus separately scrapes Kubernetes and Collector health. Grafana visualizes all local signals. Pyroscope is optional; demo profiles were disabled. The existing gateway's standard OTLP ports 4317/4318 serve other workloads. Dedicated demo ports 14317/14318 isolate the demo routing policy.

## Prepare the chart

```sh
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm show values open-telemetry/opentelemetry-demo --version 0.42.6 > demo-default-values.yaml
helm pull open-telemetry/opentelemetry-demo --version 0.42.6 --untar
```

Create a local values override based on the pinned chart defaults. Disable bundled Grafana, Prometheus, Jaeger, OpenSearch, eBPF profiler and OpAMP server, and duplicate host/kubelet/cluster/annotation metrics collection. Keep the application dependencies (Kafka, Valkey, database, flagd) and demo Collector. Use a single Collector Deployment. Disable profiles and Firepit export. Preserve application instrumentation, Kubernetes attributes, span_metrics connector, log/span sanitization and GenAI normalization. Redaction is not comprehensive; never enter real customer data.

Use the Collector chart's alternateConfig to supply the complete Collector config, rather than nulling individual default pipelines (the latter caused a Helm template error in the lab). Copy the chart's default Collector config first and modify it, retaining required receivers/processors/extensions. Set OTLP receiver endpoints to 0.0.0.0:4317 and :4318. Replace external exporters with:

```yaml
exporters:
  otlp_grpc/gateway:
    endpoint: otel-gateway.observability.svc.cluster.local:14317
    tls:
      insecure: true
    sending_queue:
      enabled: true
    retry_on_failure:
      enabled: true
```

Set logs and metrics pipelines to export to otlp_grpc/gateway, and traces to both otlp_grpc/gateway and span_metrics. Retain span_metrics as a metrics receiver. Remove disabled exporter references and self-telemetry OTLP loops. Retain health_check and batch. Configure load-generator environment LOCUST_USERS=1, LOCUST_AUTOSTART=false, LOCUST_BROWSER_TRAFFIC_ENABLED=false. Consult the actual chart keys before applying; this is a configuration recipe, not a complete values file.

## Gateway configuration

Merge the following fragment into your existing gateway configuration, adapting exporter names to the deployed backends. Do not replace existing pipelines. Ensure the named processors/exporters already exist.

```yaml
receivers:
  otlp/demo:
    protocols:
      grpc:
        endpoint: 0.0.0.0:14317
      http:
        endpoint: 0.0.0.0:14318
service:
  pipelines:
    metrics/demo:
      receivers: [otlp/demo]
      processors: [memory_limiter, batch]
      exporters: [prometheusremotewrite/mimir]
    logs/demo:
      receivers: [otlp/demo]
      processors: [memory_limiter, batch]
      exporters: [otlphttp/loki]
    traces/demo:
      receivers: [otlp/demo]
      processors: [memory_limiter, batch]
      exporters: [otlp_grpc/tempo]
```

Expose both ports on the gateway ClusterIP Service. Preserve any existing metric-label transform in the metrics pipeline. Validate the complete configuration using the exact Collector image and environment with the validate subcommand before applying. Back up the ConfigMap securely, patch only its config key, restart the gateway and wait for rollout. A restart can briefly interrupt ingestion. Keep a rollback copy; never commit credentials.

Render and inspect the complete chart before installation:

```sh
helm template otel-demo ./opentelemetry-demo -n otel-demo -f values-lab.yaml > demo-rendered.yaml
helm upgrade --install otel-demo ./opentelemetry-demo -n otel-demo --create-namespace -f values-lab.yaml --wait --timeout 15m
kubectl -n otel-demo get deploy,pods,svc
```

The values-lab.yaml file must be prepared as described above; it is not yet included as a verified portable artifact.

## Access and test

Run on the browser's machine, in separate terminals:

```sh
kubectl -n otel-demo port-forward svc/frontend-proxy 18000:8080
kubectl -n otel-demo port-forward svc/load-generator 18089:8089
```

Open http://127.0.0.1:18000 and http://127.0.0.1:18089. Start one Locust user for 5–10 minutes, then stop. Port-forwarding is for UI access only; telemetry uses cluster networking. Verify Tempo with TraceQL { resource.service.name = "checkout" }, Loki with {service_name="checkout"} if that label is mapped, and Mimir by discovering actual metric names.

## Optional cloud exports

Create scoped cloud ingestion credentials using each provider's official instructions. Store in Kubernetes Secrets and inject environment variables; never put real tokens in Git. Configure Grafana Cloud OTLP HTTP endpoint and basic authentication (instance ID and token). Configure Splunk Observability Cloud OTLP HTTP endpoint and X-SF-Token for the correct realm and entitlement. Verify endpoint paths for each signal against provider documentation.

Add separate cloud pipelines sharing the demo receiver (or use forward connectors as in the tested configuration). Keep local pipelines unchanged. Example fragment, assuming existing cloud exporters:

```yaml
processors:
  probabilistic_sampler/demo_cloud:
    sampling_percentage: 10
  filter/demo_cloud_logs:
    error_mode: ignore
    logs:
      log_record:
        - severity_number < SEVERITY_NUMBER_WARN
  filter/demo_cloud_metrics:
    error_mode: ignore
    metrics:
      metric:
        - 'not IsMatch(name, "^(http[._].*|rpc[._].*|traces[._]span[._]metrics[._].*|gen_ai[._].*)$")'
service:
  pipelines:
    metrics/demo_cloud:
      receivers: [otlp/demo]
      processors: [memory_limiter, filter/demo_cloud_metrics, batch]
      exporters: [otlphttp/grafana_cloud, otlphttp/splunk_o11y]
    logs/demo_cloud:
      receivers: [otlp/demo]
      processors: [memory_limiter, filter/demo_cloud_logs, batch]
      exporters: [otlphttp/grafana_cloud]
    traces/demo_cloud:
      receivers: [otlp/demo]
      processors: [memory_limiter, probabilistic_sampler/demo_cloud, batch]
      exporters: [otlphttp/grafana_cloud, otlphttp/splunk_o11y]
```

This shared-receiver variant is an illustrative alternative to the forward-connector configuration used in the lab; validate against the installed Collector version. The metric allowlist is provisional: inspect actual metric names and adjust. WARN filtering drops unspecified severity. Sampling is not a hard quota and can bias backend-generated RED metrics. Generate accurate RED metrics before sampling for production. Splunk logs are not enabled here; separate log ingestion/entitlement is needed.

User confirmed telemetry visible in Grafana OSS, Grafana Cloud and Splunk Observability Cloud. Individual signal completeness and sampling ratios still need verification. Grafana Cloud Application Observability service inventory remains unresolved; see operations notes.

Official references: https://opentelemetry.io/docs/demo/kubernetes-deployment/ ; https://grafana.com/docs/grafana-cloud/send-data/otlp/ ; https://help.splunk.com/en/splunk-observability-cloud
