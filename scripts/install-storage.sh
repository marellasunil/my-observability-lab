#!/usr/bin/env bash
source "$(dirname "$0")/common.sh" "$@"
show_mode
if [[ $MODE == --dry-run ]]; then log "Would install Local Path Provisioner ${LOCAL_PATH_VERSION}"; exit 0; fi
require_cmd kubectl; kubectl cluster-info >/dev/null
if kubectl get storageclass local-path >/dev/null 2>&1; then log 'local-path StorageClass already exists; skipping'; exit 0; fi
url="https://raw.githubusercontent.com/rancher/local-path-provisioner/${LOCAL_PATH_VERSION}/deploy/local-path-storage.yaml"
log "Applying pinned upstream manifest: $url"
kubectl apply -f "$url"
# Only set default if no default StorageClass already exists.
if ! kubectl get storageclass -o jsonpath='{range .items[*]}{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{"\n"}{end}' | grep -qx true; then
  kubectl annotate storageclass local-path storageclass.kubernetes.io/is-default-class=true --overwrite
fi
