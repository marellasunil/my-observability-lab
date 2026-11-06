#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Never source an untrusted configuration file. Review local lab.env before using.
if [[ -f "$ROOT_DIR/config/lab.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/config/lab.env"
else
  # shellcheck disable=SC1091
  source "$ROOT_DIR/config/lab.env.example"
fi
MODE="${1:---dry-run}"
[[ "$MODE" == --dry-run || "$MODE" == --apply ]] || { echo 'Usage: script [--dry-run|--apply]' >&2; exit 2; }
log(){ printf '[%s] %s\n' "$(basename "$0")" "$*"; }
require_root(){ [[ $EUID -eq 0 ]] || { log 'Run with sudo for --apply'; exit 1; }; }
require_cmd(){ command -v "$1" >/dev/null || { log "Missing command: $1"; exit 1; }; }
cluster_initialized(){ [[ -s /etc/kubernetes/admin.conf || -s /etc/kubernetes/kubelet.conf || -d /var/lib/etcd/member ]]; }
assert_fresh_node(){ if cluster_initialized; then log 'Existing Kubernetes node detected: refusing to modify'; exit 1; fi; }
show_mode(){ log "mode=$MODE node=${LAB_NODE_IP} podCIDR=${POD_NETWORK_CIDR}"; }
