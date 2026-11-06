#!/usr/bin/env bash
source "$(dirname "$0")/common.sh" --dry-run
require_cmd kubectl
log 'Cluster nodes'; kubectl get nodes -o wide
log 'System pods'; kubectl get pods -n kube-system
log 'Storage classes'; kubectl get storageclass
log 'Observability workloads'; kubectl get pods,svc,pvc -n observability || true
log 'Node resource usage (may be unavailable until Metrics Server is ready)'; kubectl top nodes || true
log 'Helm releases'; if command -v helm >/dev/null; then helm list -n observability; fi
log 'Validation inspection complete (read-only)'
