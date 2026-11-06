#!/usr/bin/env bash
source "$(dirname "$0")/common.sh" "$@"
show_mode
if [[ $MODE == --dry-run ]]; then log "Would install Metrics Server ${METRICS_SERVER_VERSION}"; exit 0; fi
require_cmd kubectl; kubectl cluster-info >/dev/null
if kubectl -n kube-system get deployment metrics-server >/dev/null 2>&1; then log 'Metrics Server exists; refusing overwrite'; exit 0; fi
url="https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"
kubectl apply -f "$url"
log 'Installed without insecure TLS flag. If kubelet certificate validation fails, see docs/installation.md for lab-only workaround.'
