#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---dry-run}"

if [[ "$MODE" != "--dry-run" ]]; then
  echo "Only --dry-run is implemented."
  echo "Usage: $0 --dry-run"
  exit 1
fi

echo "======================================"
echo " Observability Lab - Fedora Bootstrap"
echo "======================================"

echo
echo "1. Operating system"
cat /etc/os-release | grep -E '^(NAME|VERSION_ID)='

echo
echo "2. Hostname"
hostnamectl --static

echo
echo "3. CPU"
nproc

echo
echo "4. Memory"
free -h

echo
echo "5. Disk"
df -h /

echo
echo "6. Swap"
swapon --show

echo
echo "7. Required kernel modules"
for module in overlay br_netfilter; do
  if lsmod | grep -q "^${module} "; then
    echo "[OK] $module"
  else
    echo "[INFO] $module is not currently loaded"
  fi
done

echo
echo "8. Kubernetes networking settings"
for key in \
  net.ipv4.ip_forward \
  net.bridge.bridge-nf-call-iptables; do
  if sysctl -n "$key" >/dev/null 2>&1; then
    echo "$key = $(sysctl -n "$key")"
  else
    echo "$key = unavailable"
  fi
done

echo
echo "9. Installed tools"
for tool in \
  containerd kubeadm kubelet kubectl helm; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "[OK] $tool"
  else
    echo "[MISSING] $tool"
  fi
done

echo
echo "10. Container runtime"
if command -v systemctl >/dev/null 2>&1; then
  systemctl is-active containerd || true
  systemctl is-active kubelet || true
fi

echo
echo "Bootstrap inspection completed."
echo "No system changes were made."
