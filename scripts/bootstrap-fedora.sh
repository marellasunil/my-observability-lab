#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$SCRIPT_DIR/common.sh" ]]; then
  echo "ERROR: Missing dependency: $SCRIPT_DIR/common.sh" >&2
  exit 1
fi

source "$SCRIPT_DIR/common.sh"

MODE="${1:---dry-run}"

case "$MODE" in
  --dry-run|--apply) ;;
  *)
    echo "Usage: $0 [--dry-run|--apply]" >&2
    exit 1
    ;;
esac

echo "======================================"
echo " Observability Lab - Fedora Bootstrap"
echo "======================================"

echo "Mode: $MODE"
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/fedora-release)"
echo "CPU cores: $(nproc)"

free -h
df -h /

echo
echo "Swap:"
swapon --show

echo
echo "Kernel modules:"
for module in overlay br_netfilter; do
  if lsmod | grep -q "^${module} "; then
    echo "[OK] $module"
  else
    echo "[INFO] $module is not loaded"
  fi
done

echo
echo "Kubernetes sysctl settings:"
for key in net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables; do
  sysctl "$key" 2>/dev/null || true
done

if [[ "$MODE" == "--dry-run" ]]; then
  echo
  echo "[DRY-RUN] No system modifications performed."
  exit 0
fi

echo "ERROR: Bootstrap --apply is disabled pending installer safety validation." >&2
exit 1
