# Kubeadm Cluster Installation with Ansible

This guide provides step-by-step instructions to install a Kubernetes cluster using kubeadm on Ubuntu 22.04 via Ansible running locally on the target server.

## Prerequisites

- Fresh Ubuntu 22.04 server with IP: 192.168.9.182
- Root or sudo access to the server
- Internet connectivity

## Installation Steps

### Step 1: Login to Your Server

```bash
ssh administrator@192.168.9.182
sudo su -
```

### Step 2: Create Project Directory

```bash
mkdir -p ~/kubeadm-ansible
cd ~/kubeadm-ansible
```

### Step 3: Install Ansible

```bash
apt update
apt install -y software-properties-common
add-apt-repository --yes --update ppa:ansible/ansible
apt install -y ansible
```

Verify installation:
```bash
ansible --version
```

### Step 4: Create Ansible Configuration Files

#### Create inventory.ini

```bash
cat > inventory.ini <<'EOF'
[master]
192.168.9.182 ansible_connection=local

[master:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
```

#### Create ansible.cfg

```bash
cat > ansible.cfg <<'EOF'
[defaults]
inventory = inventory.ini
host_key_checking = False
timeout = 30
deprecation_warnings = False

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
EOF
```

#### Create kubeadm-playbook.yaml

Copy the kubeadm-playbook.yaml file content to this location or download it.

```bash
# Create the file using vi or nano
vi kubeadm-playbook.yaml
# OR
nano kubeadm-playbook.yaml
```

Paste the entire playbook content and save the file.

### Step 5: Verify Files

```bash
ls -la
```

You should see:
- ansible.cfg
- inventory.ini
- kubeadm-playbook.yaml

### Step 6: Test Ansible Connectivity

```bash
ansible master -m ping
```

Expected output:
```
192.168.9.182 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### Step 7: Run the Playbook

```bash
ansible-playbook kubeadm-playbook.yaml
```

This process will take approximately 10-15 minutes. The playbook will:
- Disable swap
- Configure kernel modules
- Install containerd runtime
- Install kubeadm, kubelet, kubectl (v1.29.6)
- Initialize Kubernetes cluster
- Install Calico CNI
- Wait for node to be Ready

### Step 8: Verify Installation

After the playbook completes, verify the cluster:

```bash
kubectl get nodes
```

Expected output:
```
NAME     STATUS   ROLES           AGE   VERSION
master   Ready    control-plane   5m    v1.29.6
```

Check all pods:
```bash
kubectl get pods -A
```

All pods should be in Running status.

Check cluster info:
```bash
kubectl cluster-info
```

## Configuration Details

The playbook uses the following configuration:

- Kubernetes Version: 1.29.6
- Container Runtime: containerd 1.7.14
- CNI Plugin: Calico v3.28.0
- Pod Network CIDR: 192.168.0.0/16
- API Server Address: 192.168.9.182
- Node Name: master

## Post-Installation

### Access Kubeconfig

The kubeconfig is automatically set up at:
```bash
/root/.kube/config
```

### Get Join Command for Worker Nodes

If you want to add worker nodes later:

```bash
kubeadm token create --print-join-command
```

### Deploy a Test Application

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get svc nginx
```

## Troubleshooting

### Check Ansible Syntax

```bash
ansible-playbook kubeadm-playbook.yaml --syntax-check
```

### Run Playbook in Verbose Mode

```bash
ansible-playbook kubeadm-playbook.yaml -vvv
```

### Check Kubelet Status

```bash
systemctl status kubelet
journalctl -u kubelet -n 50
```

### Check Containerd Status

```bash
systemctl status containerd
journalctl -u containerd -n 50
```

### Node Not Ready

If the node stays in NotReady status:

```bash
# Check pod network
kubectl get pods -n kube-system

# Check Calico pods
kubectl get pods -n calico-system

# Restart kubelet
systemctl restart kubelet
```

### Re-run Playbook

The playbook is idempotent and can be run multiple times safely:

```bash
cd ~/kubeadm-ansible
ansible-playbook kubeadm-playbook.yaml
```

## Common Issues and Solutions

### Issue: Swap is enabled
**Solution**: The playbook automatically disables swap. If it persists, manually run:
```bash
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

### Issue: Port already in use
**Solution**: Check if any services are using Kubernetes ports:
```bash
netstat -tlnp | grep -E '6443|10250|10251|10252'
```

### Issue: Containerd not starting
**Solution**: Check containerd logs and restart:
```bash
journalctl -u containerd -n 100
systemctl restart containerd
```

## Cluster Management

### View All Resources

```bash
kubectl get all -A
```

### View Node Details

```bash
kubectl describe node master
```

### View Events

```bash
kubectl get events -A --sort-by='.lastTimestamp'
```

### Check Resource Usage

```bash
kubectl top nodes
kubectl top pods -A
```

Note: Metrics server needs to be installed for top commands to work.

## Cleanup and Reset

To completely remove the cluster and start fresh:

```bash
# Reset kubeadm
kubeadm reset -f

# Clean up files
rm -rf /etc/cni /etc/kubernetes /var/lib/dockershim /var/lib/etcd /var/lib/kubelet /var/lib/calico
rm -rf ~/.kube

# Clean iptables
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X

# Stop services
systemctl stop kubelet containerd

# Remove packages (optional)
apt-mark unhold kubelet kubeadm kubectl
apt remove -y kubelet kubeadm kubectl
```

Then you can re-run the playbook to reinstall.

## Upgrading the Cluster

This installation uses Kubernetes v1.29.6, which allows you to upgrade to v1.30 later. Upgrade instructions can be found in the official Kubernetes documentation.

## Security Considerations

- Change default passwords if using password authentication
- Configure firewall rules as needed
- Enable RBAC (enabled by default)
- Consider using network policies
- Regularly update and patch the system

## Additional Resources

- Kubernetes Documentation: https://kubernetes.io/docs/
- Kubeadm Documentation: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
- Calico Documentation: https://docs.tigera.io/calico/latest/about/
- Ansible Documentation: https://docs.ansible.com/

## Support

For issues or questions:
- Check kubelet logs: `journalctl -u kubelet -f`
- Check containerd logs: `journalctl -u containerd -f`
- Review Kubernetes events: `kubectl get events -A`
- Check pod logs: `kubectl logs -n <namespace> <pod-name>`

## File Structure

```
~/kubeadm-ansible/
├── ansible.cfg
├── inventory.ini
├── kubeadm-playbook.yaml
└── README.md
```

## Notes

- This setup creates a single-node cluster (master only)
- To add worker nodes, use the kubeadm join command
- The cluster uses containerd as the container runtime
- Calico is used for pod networking
- All Kubernetes packages are held to prevent automatic upgrades
- The playbook is idempotent and safe to run multiple times