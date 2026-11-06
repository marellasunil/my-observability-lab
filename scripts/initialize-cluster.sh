#!/usr/bin/env bash
source "$(dirname "$0")/common.sh" "$@"
show_mode
if [[ $MODE == --dry-run ]]; then
  log "Would run kubeadm init --apiserver-advertise-address=$LAB_NODE_IP --pod-network-cidr=$POD_NETWORK_CIDR"
  log 'This is intentionally a separate, explicit operation on a new node.'
  exit 0
fi
require_root; assert_fresh_node
require_cmd kubeadm; require_cmd containerd
[[ -S /run/containerd/containerd.sock ]] || { log 'Containerd socket unavailable'; exit 1; }
[[ "$(swapon --noheadings | wc -l)" -eq 0 ]] || { log 'Swap enabled: disable manually first'; exit 1; }
[[ "$(sysctl -n net.ipv4.ip_forward)" == 1 ]] || { log 'IP forwarding not enabled'; exit 1; }
ip -4 addr show dev "$LAB_NETWORK_INTERFACE" | grep -Fq "$LAB_NODE_IP/" || { log 'Node IP not present on configured interface'; exit 1; }
log 'Initializing fresh cluster; this changes the host'
kubeadm init --apiserver-advertise-address="$LAB_NODE_IP" --pod-network-cidr="$POD_NETWORK_CIDR" --cri-socket=unix:///run/containerd/containerd.sock
log 'Configure kubeconfig manually; install Calico before scheduling workloads.'
