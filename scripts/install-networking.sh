#!/usr/bin/env bash
source "$(dirname "$0")/common.sh" "$@"
show_mode
if [[ $MODE == --dry-run ]]; then
  log "Would install Tigera operator ${CALICO_VERSION} and Calico VXLAN CIDR ${POD_NETWORK_CIDR}"
  log 'Would add LAN-scoped firewall rules; does NOT remove existing broad port allowances'
  exit 0
fi
require_cmd kubectl; require_cmd helm
kubectl cluster-info >/dev/null
if kubectl get installation.operator.tigera.io default >/dev/null 2>&1; then
  log 'Existing Calico installation detected; refusing to replace'; exit 1
fi
helm repo add projectcalico https://docs.tigera.io/calico/charts --force-update
helm repo update projectcalico
helm show chart projectcalico/tigera-operator --version "${CALICO_VERSION#v}" >/dev/null
helm upgrade --install calico projectcalico/tigera-operator --version "${CALICO_VERSION#v}" -n tigera-operator --create-namespace --wait --timeout 5m
kubectl wait --for=condition=Established crd/installations.operator.tigera.io --timeout=120s
cat <<YAML | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
      - cidr: ${POD_NETWORK_CIDR}
        encapsulation: VXLAN
        natOutgoing: Enabled
        nodeSelector: all()
YAML
log 'Calico installation requested; inspect node readiness and networking before continuing.'
log 'Firewall is NOT changed automatically. Review docs/firewall.md.'
