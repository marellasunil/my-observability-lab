#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="observability"

GRAFANA_CHART_VERSION="14.4.0"
PROMETHEUS_CHART_VERSION="92.21.2"

MODE="${1:---dry-run}"

if [[ "$MODE" != "--dry-run" && "$MODE" != "--apply" ]]; then
  echo "Usage: $0 [--dry-run|--apply]"
  exit 1
fi

for cmd in kubectl helm; do
  command -v "$cmd" >/dev/null || {
    echo "Missing required command: $cmd"
    exit 1
  }
done

kubectl cluster-info >/dev/null

helm repo add grafana-community \
  https://grafana-community.github.io/helm-charts \
  --force-update

helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts \
  --force-update

helm repo update

echo "Validating Helm configurations..."

echo "Downloading pinned Helm charts..."

CHART_DIR="$(mktemp -d)"
trap 'rm -rf "$CHART_DIR"' EXIT

helm pull grafana-community/grafana \
  --version "$GRAFANA_CHART_VERSION" \
  --destination "$CHART_DIR"

helm pull prometheus-community/kube-prometheus-stack \
  --version "$PROMETHEUS_CHART_VERSION" \
  --destination "$CHART_DIR"

echo "Validating Helm configurations..."

helm lint "$CHART_DIR/grafana-${GRAFANA_CHART_VERSION}.tgz" \
  --values "$ROOT_DIR/observability/grafana/values.yaml"

helm lint "$CHART_DIR/kube-prometheus-stack-${PROMETHEUS_CHART_VERSION}.tgz" \
  --values "$ROOT_DIR/observability/prometheus/values.yaml"

if [[ "$MODE" == "--dry-run" ]]; then
  echo "Dry-run complete. No workloads modified."
  echo "Use --apply to install or upgrade monitoring."
  exit 0
fi

echo "Installing Prometheus..."
helm upgrade --install prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --version "$PROMETHEUS_CHART_VERSION" \
  --values "$ROOT_DIR/observability/prometheus/values.yaml" \
  --wait \
  --timeout 10m

echo "Installing Grafana..."
helm upgrade --install grafana \
  grafana-community/grafana \
  --namespace "$NAMESPACE" \
  --version "$GRAFANA_CHART_VERSION" \
  --values "$ROOT_DIR/observability/grafana/values.yaml" \
  --wait \
  --timeout 10m

echo "Deploying Grafana NodePort service..."

kubectl apply -f \
  "$ROOT_DIR/observability/grafana/grafana-nodeport.yaml"

echo "Monitoring installation complete."

kubectl get pods -n "$NAMESPACE"
kubectl get svc grafana-nodeport -n "$NAMESPACE"
