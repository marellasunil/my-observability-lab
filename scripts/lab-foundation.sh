#!/usr/bin/env bash
# Non-destructive checks; only bootstrap-kind creates a cluster.
set -euo pipefail
usage() {
  echo "Usage: bash scripts/lab-foundation.sh {bootstrap-kind|preflight|verify|inventory} [lab-config.yaml]"
}
[[ $# -ge 1 && $# -le 2 ]] || { usage; exit 2; }
action="$1"
config="${2:-lab-config.yaml}"
case "$action" in bootstrap-kind|preflight|verify|inventory) ;; *) usage; exit 2;; esac
for tool in python3 kubectl helm; do
  command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }
done
# Parse YAML as data, never source it as shell code.
parsed="$(python3 - "$config" <<'PY'
import sys, re
import yaml
with open(sys.argv[1]) as f:
    c = yaml.safe_load(f)
cluster = c["cluster"]
values = [cluster["type"], cluster["context"], cluster["name"], c["storage"]["className"]]
if values[0] not in ("kind", "existing"):
    raise SystemExit("cluster.type must be kind or existing")
for v in values:
    if not isinstance(v, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", v):
        raise SystemExit("Invalid cluster or storage identifier")
if values[0] == "kind" and values[1] != "kind-" + values[2]:
    raise SystemExit("Kind context must equal kind-<cluster.name>")
print(" ".join(values))
PY
)"
read -r type context name storage <<< "$parsed"
k() { kubectl --context "$context" "$@"; }
h() { helm --kube-context "$context" "$@"; }
if [[ "$action" == bootstrap-kind ]]; then
  [[ "$type" == kind ]] || { echo "Set cluster.type to kind first" >&2; exit 2; }
  command -v kind >/dev/null || { echo "Install Kind first" >&2; exit 1; }
  clusters="$(kind get clusters)"
  if grep -Fxq "$name" <<< "$clusters"; then
    echo "Kind cluster already exists: $name"
  else
    kind create cluster --name "$name" --wait 5m
  fi
fi
echo "Checking explicit Kubernetes context: $context"
k get --raw=/readyz
k get nodes -o wide
k wait --for=condition=Ready nodes --all --timeout=120s
k get storageclass "$storage"
case "$action" in
  bootstrap-kind|preflight)
    k get resourcequota -A
    k get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory
    echo "Preflight passed. Verify available disk and PVC provisioning separately."
    ;;
  inventory)
    # Metadata only: no Secret objects, ConfigMap contents, env or Helm values.
    h list -A
    k get deployments,statefulsets,daemonsets,services,pvc -n observability
    if k get namespace otel-demo >/dev/null 2>&1; then
      k get deployments,services,pvc -n otel-demo
    fi
    ;;
  verify)
    h list -A
    k get pods,pvc,svc -n observability
    k -n observability rollout status deployment/otel-gateway --timeout=120s
    if k get namespace otel-demo >/dev/null 2>&1; then
      k get pods,svc -n otel-demo
      k -n otel-demo rollout status deployment/frontend --timeout=120s
      echo "Check all demo workloads; stopped workloads may be intentional."
    fi
    echo "Readiness is not ingestion proof. Verify actual metrics, logs and traces in each backend."
    ;;
esac
