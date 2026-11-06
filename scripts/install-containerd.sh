#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---dry-run}"
TARGET_VERSION="2.4.2"

if [[ "$MODE" != "--dry-run" && "$MODE" != "--apply" ]]; then
  echo "Usage: $0 [--dry-run|--apply]"
  exit 1
fi

if [[ ! -f /etc/fedora-release ]]; then
  echo "ERROR: This installer supports Fedora only."
  exit 1
fi

echo "====================================="
echo " Observability Lab - Containerd"
echo "====================================="

echo "Target version: $TARGET_VERSION"
echo "Mode: $MODE"

if command -v containerd >/dev/null 2>&1; then
  echo "Existing: $(containerd --version)"
else
  echo "Containerd is not installed."
fi

if [[ -f /etc/kubernetes/admin.conf ]] ||
   [[ -f /etc/kubernetes/kubelet.conf ]]; then
  echo "Existing Kubernetes configuration detected."
  echo "Containerd installation/configuration changes are blocked."
  exit 0
fi

if [[ "$MODE" == "--dry-run" ]]; then
  echo "Dry-run complete. No changes made."
  exit 0
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: --apply requires sudo."
  exit 1
fi

dnf install -y containerd

INSTALLED_VERSION="$(containerd --version | awk '{print $3}' | sed 's/^v//')"

if [[ "$INSTALLED_VERSION" != "$TARGET_VERSION" ]]; then
  echo "ERROR: Installed version $INSTALLED_VERSION differs from $TARGET_VERSION."
  echo "Stopping before changing configuration."
  exit 1
fi

mkdir -p /etc/containerd

if [[ -e /etc/containerd/config.toml ]]; then
  echo "Existing containerd config detected. Refusing to overwrite."
  exit 1
fi

containerd config default > /etc/containerd/config.toml

# Configure systemd cgroups for runc.
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml

systemctl enable --now containerd

echo "Containerd installed and started."
