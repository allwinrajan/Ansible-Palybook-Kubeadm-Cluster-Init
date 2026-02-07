# Kubernetes Cluster Deployment Guide
## 1 Master + 2 Worker Setup

---

## Cluster Configuration

### Node Details
- **Master Node**: 192.168.9.182 (k8s-master)
- **Worker Node 1**: 192.168.9.171 (k8s-worker1)
- **Worker Node 2**: 192.168.9.173 (k8s-worker2)

### Network Configuration
- **Pod Network CIDR**: 192.168.0.0/16
- **Service CIDR**: 10.96.0.0/12
- **Kubernetes Version**: 1.29.6-1.1
- **CNI Plugin**: Calico v3.28.0

---

## Prerequisites

1. **All nodes must have**:
   - Ubuntu 22.04 LTS
   - Root or sudo access
   - SSH access configured
   - At least 2 CPUs and 2GB RAM
   - Network connectivity between all nodes

2. **Control machine** (where you run Ansible):
   - Ansible installed
   - SSH key-based authentication to all nodes

---

## File Structure

```
k8s-cluster/
├── inventory.ini                  # Inventory file with node IPs
├── group_vars/
│   └── all.yml                    # Environment variables (IPs, versions)
├── 00-reset-cluster.yml           # Reset existing cluster
├── 01-common-prerequisites.yml    # Install prerequisites on all nodes
├── 02-install-calico.yml          # Install Calico CNI (run after init)
├── master-init.sh                 # Manual master init script
├── worker-join.sh                 # Manual worker join script
└── DEPLOYMENT-GUIDE.md            # This file
```

---

## Deployment Steps

### STEP 1: Configure Environment Variables

Edit `group_vars/all.yml` to update IPs if needed:

```bash
vim group_vars/all.yml
```

**Key variables to check**:
```yaml
master_ip: "192.168.9.182"
worker1_ip: "192.168.9.171"
worker2_ip: "192.168.9.173"
pod_network_cidr: "192.168.0.0/16"
```

### STEP 2: Update Inventory File

Edit `inventory.ini` and verify node IPs:

```bash
vim inventory.ini
```

Verify SSH connectivity to all nodes:

```bash
ansible all -i inventory.ini -m ping
```

**Expected output**: All nodes should return `SUCCESS`

---

### STEP 3: Reset Existing Cluster (IMPORTANT!)

Since you have an existing cluster on the master node, reset it first:

```bash
ansible-playbook -i inventory.ini 00-reset-cluster.yml
```

**What this does**:
- Runs `kubeadm reset -f` on all nodes
- Removes all Kubernetes configurations
- Cleans up CNI and iptables rules
- Restarts containerd service
- Prepares nodes for fresh installation

**Verify reset on master**:
```bash
ssh administrator@192.168.9.182 "sudo kubectl get nodes"
# Should return: connection refused or command not found
```

---

### STEP 4: Install Common Prerequisites on All Nodes

Run the common prerequisites playbook on all nodes (master + workers):

```bash
ansible-playbook -i inventory.ini 01-common-prerequisites.yml
```

**What this installs**:
- ✅ Disables swap
- ✅ Loads kernel modules (overlay, br_netfilter)
- ✅ Configures network parameters
- ✅ Installs containerd (v1.7.14)
- ✅ Installs runc (v1.1.12)
- ✅ Installs CNI plugins (v1.5.0)
- ✅ Installs kubeadm, kubelet, kubectl (v1.29.6)
- ✅ Configures crictl runtime endpoint

**Time required**: 5-10 minutes

**Verify installation**:
```bash
# Check on all nodes
ansible all -i inventory.ini -a "kubeadm version"
ansible all -i inventory.ini -a "systemctl status containerd" -b
```

---

### STEP 5: Initialize Master Node (MANUAL STEP)

**Option A: Using the provided script (RECOMMENDED)**

Copy the script to master and execute:

```bash
# Copy script to master
scp master-init.sh administrator@192.168.9.182:/tmp/

# SSH to master
ssh administrator@192.168.9.182

# Run the initialization script
sudo bash /tmp/master-init.sh
```

**Option B: Manual kubeadm init command**

SSH to master node and run:

```bash
ssh administrator@192.168.9.182

sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=192.168.9.182 \
  --node-name=$(hostname) \
  --cri-socket=unix:///run/containerd/containerd.sock \
  --v=5
```

**What happens**:
- Initializes the control plane components
- Generates certificates
- Configures API server, scheduler, controller-manager
- Creates kubeconfig files

**Time required**: 2-5 minutes

**After initialization**, the script automatically:
1. Sets up kubeconfig for root and administrator users
2. Generates the join command in `/root/kubeadm-join-command.sh`

**Verify initialization**:
```bash
# On master node
sudo kubectl get nodes
sudo kubectl get pods -A
```

**Expected output**:
- Master node in `NotReady` state (this is normal - CNI not installed yet)
- CoreDNS pods in `Pending` state (waiting for CNI)

---

### STEP 6: Install Calico CNI Network Plugin

From your control machine, install Calico:

```bash
ansible-playbook -i inventory.ini 02-install-calico.yml
```

**What this does**:
- Installs Tigera operator
- Configures Calico with pod CIDR 192.168.0.0/16
- Deploys Calico pods in calico-system namespace
- Waits for all components to be ready

**Time required**: 2-5 minutes

**Verify Calico installation**:
```bash
ssh administrator@192.168.9.182 "kubectl get pods -n calico-system"
ssh administrator@192.168.9.182 "kubectl get nodes"
```

**Expected output**:
- All Calico pods in `Running` state
- Master node now in `Ready` state

---

### STEP 7: Retrieve Join Command from Master

Get the join command that workers will use:

```bash
ssh administrator@192.168.9.182 "sudo cat /root/kubeadm-join-command.sh"
```

**Example output**:
```bash
kubeadm join 192.168.9.182:6443 --token abc123.xyz456 \
  --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

**IMPORTANT**: Save this command - you'll need it for joining workers!

---

### STEP 8: Join Worker Nodes (MANUAL STEP)

**Option A: Using the provided script (RECOMMENDED)**

For each worker node:

```bash
# Copy script to worker1
scp worker-join.sh administrator@192.168.9.171:/tmp/

# SSH to worker1
ssh administrator@192.168.9.171

# Run join with the command from master
sudo bash /tmp/worker-join.sh "kubeadm join 192.168.9.182:6443 --token abc123.xyz456 --discovery-token-ca-cert-hash sha256:1234567890abcdef..."
```

Repeat for worker2 (192.168.9.173)

**Option B: Manual kubeadm join**

SSH to each worker and run:

```bash
# Worker 1
ssh administrator@192.168.9.171

sudo kubeadm join 192.168.9.182:6443 \
  --token abc123.xyz456 \
  --discovery-token-ca-cert-hash sha256:1234567890abcdef... \
  --cri-socket=unix:///run/containerd/containerd.sock

# Worker 2
ssh administrator@192.168.9.173

sudo kubeadm join 192.168.9.182:6443 \
  --token abc123.xyz456 \
  --discovery-token-ca-cert-hash sha256:1234567890abcdef... \
  --cri-socket=unix:///run/containerd/containerd.sock
```

**Time required**: 1-2 minutes per worker

---

### STEP 9: Verify Cluster is Fully Operational

From the master node, verify all nodes are joined and ready:

```bash
ssh administrator@192.168.9.182

# Check all nodes
kubectl get nodes -o wide

# Check all pods across all namespaces
kubectl get pods -A

# Check cluster info
kubectl cluster-info

# Check component status
kubectl get cs
```

**Expected output**:

```
NAME          STATUS   ROLES           AGE   VERSION
k8s-master    Ready    control-plane   10m   v1.29.6
k8s-worker1   Ready    <none>          5m    v1.29.6
k8s-worker2   Ready    <none>          5m    v1.29.6
```

All nodes should be in `Ready` state!

---

## Verification Tests

### Test 1: Deploy a Test Application

```bash
# Create a deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Check pods are distributed across workers
kubectl get pods -o wide

# Expose the deployment
kubectl expose deployment nginx --port=80 --type=NodePort

# Get the service
kubectl get svc nginx
```

### Test 2: Check Network Connectivity

```bash
# Run a test pod
kubectl run test-pod --image=busybox --restart=Never -- sleep 3600

# Test DNS resolution
kubectl exec test-pod -- nslookup kubernetes.default

# Clean up
kubectl delete pod test-pod
kubectl delete deployment nginx
kubectl delete svc nginx
```

---

## Troubleshooting

### Issue 1: Node stuck in NotReady state

```bash
# Check kubelet status
sudo systemctl status kubelet

# Check kubelet logs
sudo journalctl -u kubelet -f

# Check CNI
kubectl get pods -n calico-system
```

### Issue 2: Pods stuck in Pending state

```bash
# Describe the pod
kubectl describe pod <pod-name>

# Check node resources
kubectl describe nodes
```

### Issue 3: Join command expired

Tokens expire after 24 hours. Generate a new one:

```bash
# On master node
sudo kubeadm token create --print-join-command
```

### Issue 4: Reset and start over

```bash
# Run reset playbook
ansible-playbook -i inventory.ini 00-reset-cluster.yml

# Then start from STEP 4
```

---

## Useful Commands

### On Master Node

```bash
# View all nodes
kubectl get nodes

# View all pods
kubectl get pods -A

# View cluster events
kubectl get events -A --sort-by='.lastTimestamp'

# Get join command
sudo kubeadm token create --print-join-command

# Drain a node (for maintenance)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon a node
kubectl uncordon <node-name>

# Remove a node from cluster
kubectl delete node <node-name>
```

### On Worker Nodes

```bash
# Check kubelet status
sudo systemctl status kubelet

# View kubelet logs
sudo journalctl -u kubelet -n 50

# Check container runtime
sudo crictl ps
sudo crictl pods
```

---

## Quick Reference: Complete Deployment Flow

```bash
# 1. Configure IPs
vim group_vars/all.yml

# 2. Test connectivity
ansible all -i inventory.ini -m ping

# 3. Reset existing cluster
ansible-playbook -i inventory.ini 00-reset-cluster.yml

# 4. Install prerequisites on all nodes
ansible-playbook -i inventory.ini 01-common-prerequisites.yml

# 5. Initialize master (SSH to master)
ssh administrator@192.168.9.182
sudo bash /tmp/master-init.sh
exit

# 6. Install Calico
ansible-playbook -i inventory.ini 02-install-calico.yml

# 7. Get join command
ssh administrator@192.168.9.182 "sudo cat /root/kubeadm-join-command.sh"

# 8. Join workers (SSH to each worker)
ssh administrator@192.168.9.171
sudo bash /tmp/worker-join.sh "<join-command>"
exit

ssh administrator@192.168.9.173
sudo bash /tmp/worker-join.sh "<join-command>"
exit

# 9. Verify cluster
ssh administrator@192.168.9.182 "kubectl get nodes"
```

---

## Security Notes

1. **Firewall Rules**: Ensure these ports are open:
   - Master: 6443, 2379-2380, 10250-10252
   - Workers: 10250, 30000-32767

2. **Kubeconfig Security**: 
   - Keep `/etc/kubernetes/admin.conf` secure
   - Limit access to users who need it

3. **Token Management**: 
   - Join tokens expire after 24 hours by default
   - Generate new tokens when needed

---

## Next Steps After Deployment

1. **Install Ingress Controller** (e.g., nginx-ingress)
2. **Set up MetalLB** for LoadBalancer services
3. **Install Helm** for package management
4. **Configure Persistent Storage** (e.g., NFS, Longhorn)
5. **Set up Monitoring** (e.g., Prometheus, Grafana)
6. **Configure RBAC** for user access control

---

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review logs: `journalctl -u kubelet -f`
3. Check pod events: `kubectl describe pod <pod-name>`
4. Verify network connectivity between nodes

---

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Kubernetes Version**: 1.29.6
