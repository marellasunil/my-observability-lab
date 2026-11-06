#!/usr/bin/env bash
source "$(dirname "$0")/common.sh" "$@"
show_mode
if [[ $MODE == --dry-run ]]; then
  log "Would install kubeadm/kubelet/kubectl ${KUBERNETES_VERSION} from ${KUBERNETES_MINOR} repo"
  log 'Does NOT initialize cluster; use initialize-cluster.sh separately'
  exit 0
fi
require_root; assert_fresh_node
[[ -f /etc/fedora-release ]] || { log 'Fedora required'; exit 1; }
[[ ! -f /etc/yum.repos.d/kubernetes.repo ]] || { log 'Existing Kubernetes repo: review manually before proceeding'; exit 1; }
cat >/etc/yum.repos.d/kubernetes.repo <<REPO
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
REPO
# Preflight package availability before installing.
for p in kubelet kubeadm kubectl; do
  dnf --disableexcludes=kubernetes list --showduplicates "$p" | grep -F "$KUBERNETES_VERSION" >/dev/null || { log "Pinned $p $KUBERNETES_VERSION unavailable"; exit 1; }
done
dnf install -y --disableexcludes=kubernetes "kubelet-${KUBERNETES_VERSION}" "kubeadm-${KUBERNETES_VERSION}" "kubectl-${KUBERNETES_VERSION}"
systemctl enable kubelet
log 'Packages installed; cluster NOT initialized'
