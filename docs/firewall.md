# Fedora firewall review (single-node LAN lab)

Do not blindly run these commands on a remote machine. First confirm that SSH access remains available and which zone is active:

```bash
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=FedoraWorkstation --list-all
```

On the tested XPS, LAN access is needed to TCP 6443 (API), 10250 (kubelet), 30080 (Grafana) and UDP 4789 (Calico VXLAN). The existing machine also has a broad 1025-65535 TCP/UDP allowance; LAN-scoped rich rules **do not restrict** that broad allowance. Review existing application requirements before removing anything.

Example **LAN-scoped** rich rule (adapt zone, subnet and port):

```bash
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule family="ipv4" source address="192.168.178.0/24" port port="6443" protocol="tcp" accept'
sudo firewall-cmd --reload
```

Do not expose Kubernetes API or kubelet ports directly to the internet. Single-node Calico VXLAN traffic does not need internet exposure. Firewall automation is intentionally excluded until a dedicated networking validation is complete.
