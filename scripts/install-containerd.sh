#!/usr/bin/env bash
source "$(dirname "$0")/common.sh" "$@"
show_mode
[[ -f /etc/fedora-release ]] || { log 'Fedora required'; exit 1; }
if command -v containerd >/dev/null; then log "Installed: $(containerd --version)"; else log 'Not installed'; fi
if [[ $MODE == --dry-run ]]; then
  log "Would install containerd ${CONTAINERD_VERSION}, configure SystemdCgroup and enable service on a fresh node"
  exit 0
fi
require_root; assert_fresh_node
[[ ! -e /etc/containerd/config.toml ]] || { log 'Existing config.toml detected: refusing overwrite'; exit 1; }
# Do not change an existing runtime on a fresh-looking machine.
if command -v containerd >/dev/null; then
  version="$(containerd --version | sed -nE 's/.* v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')"
  [[ "$version" == "$CONTAINERD_VERSION" ]] || { log "Version mismatch: $version != $CONTAINERD_VERSION"; exit 1; }
else
  log 'Installing containerd from configured Fedora repositories'
  dnf install -y containerd
  version="$(containerd --version | sed -nE 's/.* v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')"
  [[ "$version" == "$CONTAINERD_VERSION" ]] || { log "Installed version $version differs from pinned $CONTAINERD_VERSION; stopping"; exit 1; }
fi
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
# Fail if default format changes, rather than silently leaving cgroups wrong.
grep -q 'SystemdCgroup = false' /etc/containerd/config.toml || { log 'Unexpected containerd config format'; exit 1; }
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable --now containerd
log 'Containerd installed and configured'
