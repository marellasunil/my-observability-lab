#!/usr/bin/env bash
set -euo pipefail
[[ $# == 2 && -n "$1" && "$1" != -* ]] || exit 2
k=(kubectl --context "$1")
case "$2" in
 status) "${k[@]}" -n observability get pods; "${k[@]}" -n otel-demo get deployments;;
 stop-load) "${k[@]}" -n otel-demo scale deployment/load-generator --replicas=0;;
 start-load) "${k[@]}" -n otel-demo scale deployment/load-generator --replicas=1;;
 shop) "${k[@]}" -n otel-demo port-forward --address 127.0.0.1 svc/frontend-proxy 18000:8080;;
 grafana) "${k[@]}" -n observability port-forward --address 127.0.0.1 svc/grafana 3000:80;;
 *) exit 2;;
esac
