#!/usr/bin/env bash
# Read-only capture. Output is PRIVATE, not suitable for Git.
set -euo pipefail
umask 077
[[ $# -eq 2 ]] || { echo "Usage: bash scripts/capture-reference.sh CONTEXT PRIVATE_OUTPUT_DIRECTORY" >&2; exit 2; }
context="$1"
[[ -n "$context" && "$context" != -* ]] || exit 2
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
out="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).expanduser().resolve())' "$2")"
case "$out/" in "$root/"*) echo "Output must be outside repository" >&2; exit 2;; esac
[[ ! -e "$out" ]] || { echo "Output directory must not exist" >&2; exit 2; }
mkdir -m 700 -- "$out"
k() { kubectl --context "$context" "$@"; }
h() { helm --kube-context "$context" "$@"; }
k get --raw=/readyz > "$out/api-ready.txt"
k version -o yaml > "$out/kubernetes-version.yaml"
k get storageclass -o yaml > "$out/storageclasses.yaml"
h list -A -o json > "$out/helm-releases.json"
for ns in observability otel-demo; do
  if ! k get namespace "$ns" >/dev/null 2>&1; then continue; fi
  mkdir -m 700 "$out/$ns"
  k -n "$ns" get deployment,statefulset,daemonset,service,pvc -o yaml > "$out/$ns/workloads.yaml"
  h list -n "$ns" -o json > "$out/$ns/releases.json"
  python3 -c 'import json,sys; print("\n".join(r["name"] for r in json.load(open(sys.argv[1]))))' "$out/$ns/releases.json" > "$out/$ns/release-names.txt"
  while IFS= read -r release; do
    [[ -n "$release" ]] || continue
    [[ "$release" =~ ^[a-z0-9][a-z0-9-]*$ ]] || exit 1
    h get values "$release" -n "$ns" -o yaml > "$out/$ns/$release.values.yaml"
  done < "$out/$ns/release-names.txt"
done
if k -n observability get cm otel-gateway-config -o name >/dev/null 2>&1; then
  k -n observability get cm otel-gateway-config -o jsonpath='{.data.config\.yaml}' > "$out/observability/gateway-config.yaml"
fi
if k -n otel-demo get cm otel-collector -o name >/dev/null 2>&1; then
  k -n otel-demo get cm otel-collector -o jsonpath='{.data.relay}' > "$out/otel-demo/collector-relay.yaml"
fi
echo "Private capture complete: $out"
echo "WARNING: files may contain credentials, internal addresses and personal data. Never commit or upload this directory. Review and sanitize locally."
