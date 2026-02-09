# Kubernetes Cluster Setup - Complete Guide
## Fresh Ubuntu 22.04 Installation | 1 Master + 2 Workers

---

## 📋 Table of Contents
1. [Infrastructure Overview](#infrastructure-overview)
2. [Prerequisites Check](#prerequisites-check)
3. [Phase 1: Control Machine Setup](#phase-1-control-machine-setup)
4. [Phase 2: SSH Key Configuration](#phase-2-ssh-key-configuration)
5. [Phase 3: Ansible Installation & Configuration](#phase-3-ansible-installation--configuration)
6. [Phase 4: Node Preparation](#phase-4-node-preparation)
7. [Phase 5: Kubernetes Installation](#phase-5-kubernetes-installation)
8. [Phase 6: Master Node Initialization](#phase-6-master-node-initialization)
9. [Phase 7: Network Plugin Installation](#phase-7-network-plugin-installation)
10. [Phase 8: Worker Nodes Join](#phase-8-worker-nodes-join)
11. [Phase 9: Cluster Verification](#phase-9-cluster-verification)
12. [Troubleshooting](#troubleshooting)

---

## Infrastructure Overview

```
┌─────────────────────────────────────────────────────────┐
│                 Kubernetes Cluster                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Master Node (Control Plane)                            │
│  ├─ Hostname: KubernetesMaster                          │
│  ├─ IP: 192.168.9.182                                   │
│  ├─ Interface: ens34                                    │
│  └─ Role: Control Plane (API, Scheduler, Controller)    │
│                                                          │
│  Worker Node 1                                          │
│  ├─ Hostname: KubernetesWorker1                         │
│  ├─ IP: 192.168.9.171                                   │
│  ├─ Interface: ens34                                    │
│  └─ Role: Worker (Runs Pods)                            │
│                                                          │
│  Worker Node 2                                          │
│  ├─ Hostname: KubernetesWorker2                         │
│  ├─ IP: 192.168.9.173                                   │
│  ├─ Interface: ens34                                    │
│  └─ Role: Worker (Runs Pods)                            │
│                                                          │
│  Network Configuration                                   │
│  ├─ Pod Network CIDR: 192.168.0.0/16                    │
│  ├─ Service CIDR: 10.96.0.0/12                          │
│  └─ CNI Plugin: Calico v3.28.0                          │
└─────────────────────────────────────────────────────────┘
```

---

## Prerequisites Check

### On ALL Nodes (Master, Worker1, Worker2)

**1. Operating System**
```bash
cat /etc/os-release
# Should show: Ubuntu 22.04 LTS
```

**2. Root Access**
```bash
whoami
# Should show: root
```

**3. Network Connectivity**
```bash
# From Master
ping -c 2 192.168.9.171
ping -c 2 192.168.9.173

# From Worker1
ping -c 2 192.168.9.182
ping -c 2 192.168.9.173

# From Worker2
ping -c 2 192.168.9.182
ping -c 2 192.168.9.171
```

**4. System Resources**
```bash
# Check CPU (minimum 2 CPUs)
nproc

# Check Memory (minimum 2GB)
free -h

# Check Disk Space (minimum 20GB free)
df -h /
```

---

## Phase 1: Control Machine Setup

**You can run Ansible from ANY of these locations:**
- Your laptop/desktop (Linux/Mac/WSL)
- The master node itself (192.168.9.182)
- A separate management machine

**For this guide, we'll use the Master node as the control machine.**

### Step 1.1: Update Master Node

```bash
# SSH to master node
ssh root@192.168.9.182
# OR if already on master:
# You're already here

# Update system
apt update && apt upgrade -y
```

**Expected Output:**
```
Hit:1 http://archive.ubuntu.com/ubuntu jammy InRelease
Get:2 http://archive.ubuntu.com/ubuntu jammy-updates InRelease
...
Reading package lists... Done
```

---

## Phase 2: SSH Key Configuration

### Step 2.1: Enable Root SSH Login on ALL Nodes

**You must do this on Master, Worker1, and Worker2 FIRST!**

**On Master (192.168.9.182):**
```bash
# Edit SSH config
nano /etc/ssh/sshd_config

# Find and change these lines (remove # if commented):
# FROM:
#PermitRootLogin prohibit-password
#PasswordAuthentication yes

# TO:
PermitRootLogin yes
PasswordAuthentication yes

# Save and exit (Ctrl+X, then Y, then Enter)

# Restart SSH service
systemctl restart sshd
```

**On Worker1 (192.168.9.171):**
```bash
# SSH to worker1 as administrator first
ssh administrator@192.168.9.171
sudo su -

# Edit SSH config
nano /etc/ssh/sshd_config

# Change these lines:
PermitRootLogin yes
PasswordAuthentication yes

# Save and exit
systemctl restart sshd
exit
exit
```

**On Worker2 (192.168.9.173):**
```bash
# SSH to worker2 as administrator first
ssh administrator@192.168.9.173
sudo su -

# Edit SSH config
nano /etc/ssh/sshd_config

# Change these lines:
PermitRootLogin yes
PasswordAuthentication yes

# Save and exit
systemctl restart sshd
exit
exit
```

**Quick method - do this on ALL three nodes:**
```bash
# On each node, run as root:
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
```

**Verify SSH configuration on each node:**
```bash
grep -E "^PermitRootLogin|^PasswordAuthentication" /etc/ssh/sshd_config
```

**Expected Output:**
```
PermitRootLogin yes
PasswordAuthentication yes
```

### Step 2.2: Set Root Password on All Nodes

**If root doesn't have a password, set it:**

**On Master:**
```bash
# As administrator user
sudo passwd root
# Enter new password twice
```

**On Worker1:**
```bash
ssh administrator@192.168.9.171
sudo passwd root
# Enter new password twice
exit
```

**On Worker2:**
```bash
ssh administrator@192.168.9.173
sudo passwd root
# Enter new password twice
exit
```

### Step 2.3: Test Root SSH Login

**From Master, test root SSH to all nodes:**
```bash
# Test Master (should ask for password)
ssh root@192.168.9.182 "hostname"
# Type password when prompted
# Should output: KubernetesMaster

# Test Worker1 (should ask for password)
ssh root@192.168.9.171 "hostname"
# Type password when prompted
# Should output: KubernetesWorker1

# Test Worker2 (should ask for password)
ssh root@192.168.9.173 "hostname"
# Type password when prompted
# Should output: KubernetesWorker2
```

### Step 2.4: Generate SSH Key on Master (Control Machine)

```bash
# On master node (192.168.9.182) as root
ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""
```

**Expected Output:**
```
Generating public/private rsa key pair.
Your identification has been saved in /root/.ssh/id_rsa
Your public key has been saved in /root/.ssh/id_rsa.pub
```

### Step 2.5: Copy SSH Key to Master (itself)

```bash
# On master node as root
ssh-copy-id root@192.168.9.182
# Type 'yes' when prompted
# Enter root password when prompted
```

**Expected Output:**
```
Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@192.168.9.182'"
```

### Step 2.6: Copy SSH Key to Worker1

```bash
# On master node as root
ssh-copy-id root@192.168.9.171
# Type 'yes' when prompted
# Enter root password when prompted
```

**Expected Output:**
```
Number of key(s) added: 1
```

### Step 2.7: Copy SSH Key to Worker2

```bash
# On master node as root
ssh-copy-id root@192.168.9.173
# Type 'yes' when prompted
# Enter root password when prompted
```

**Expected Output:**
```
Number of key(s) added: 1
```

### Step 2.8: Test SSH Connectivity (Passwordless)

```bash
# On master node as root
ssh root@192.168.9.182 "hostname"
# Should output: KubernetesMaster (NO password prompt)

ssh root@192.168.9.171 "hostname"
# Should output: KubernetesWorker1 (NO password prompt)

ssh root@192.168.9.173 "hostname"
# Should output: KubernetesWorker2 (NO password prompt)
```

**✅ Checkpoint:** You should be able to SSH to all nodes without entering a password.

---

## Phase 3: Ansible Installation & Configuration

### Step 3.1: Fix Locale Settings (Required for Ansible)

**Ansible requires UTF-8 locale. Fix this first:**

```bash
# On master node (192.168.9.182)
# Generate UTF-8 locale
locale-gen en_US.UTF-8

# Set system locale
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Export for current session
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Add to bashrc for persistence
echo 'export LANG=en_US.UTF-8' >> /root/.bashrc
echo 'export LC_ALL=en_US.UTF-8' >> /root/.bashrc

# Verify locale
locale
```

**Expected Output:**
```
LANG=en_US.UTF-8
LANGUAGE=
LC_CTYPE="en_US.UTF-8"
LC_NUMERIC="en_US.UTF-8"
LC_TIME="en_US.UTF-8"
LC_COLLATE="en_US.UTF-8"
LC_MONETARY="en_US.UTF-8"
LC_MESSAGES="en_US.UTF-8"
LC_PAPER="en_US.UTF-8"
LC_NAME="en_US.UTF-8"
LC_ADDRESS="en_US.UTF-8"
LC_TELEPHONE="en_US.UTF-8"
LC_MEASUREMENT="en_US.UTF-8"
LC_IDENTIFICATION="en_US.UTF-8"
LC_ALL=en_US.UTF-8
```

### Step 3.2: Install Ansible on Master

```bash
# On master node (192.168.9.182)
apt update
apt install -y software-properties-common
add-apt-repository -y ppa:ansible/ansible
apt update
apt install -y ansible
```

**Expected Output:**
```
...
Setting up ansible (10.x.x)
Processing triggers for man-db
```

### Step 3.3: Verify Ansible Installation

```bash
ansible --version
```

**Expected Output:**
```
ansible [core 2.17.x]
  config file = /etc/ansible/ansible.cfg
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible
  python version = 3.10.x
```

**If you see "ERROR: Ansible requires the locale encoding to be UTF-8":**
```bash
# Run locale fix again
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
ansible --version
```

### Step 3.4: Create Project Directory

```bash
# On master node
mkdir -p /root/k8s-cluster
cd /root/k8s-cluster
```

### Step 3.5: Download Playbook Files

**Option A: If you have the files on your laptop, use SCP:**
```bash
# From your laptop/desktop, run:
scp -r /path/to/k8s-cluster/* root@192.168.9.182:/root/k8s-cluster/
```

**Option B: Create files manually (I'll provide content for each file next)**

For now, let's create the essential files:

**Create inventory.ini:**
```bash
cat > /root/k8s-cluster/inventory.ini << 'EOF'
[all:vars]
ansible_user=root
ansible_become=yes
ansible_become_method=sudo

[master]
k8s-master ansible_host=192.168.9.182

[workers]
k8s-worker1 ansible_host=192.168.9.171
k8s-worker2 ansible_host=192.168.9.173

[cluster:children]
master
workers
EOF
```

**Create group_vars/all.yml:**
```bash
mkdir -p /root/k8s-cluster/group_vars

cat > /root/k8s-cluster/group_vars/all.yml << 'EOF'
---
# Kubernetes Cluster Configuration
kubernetes_version: "1.29.6-1.1"
pod_network_cidr: "192.168.0.0/16"
service_cidr: "10.96.0.0/12"

# Master Node Configuration
master_ip: "192.168.9.182"
master_hostname: "k8s-master"

# Worker Nodes Configuration
worker1_ip: "192.168.9.171"
worker1_hostname: "k8s-worker1"

worker2_ip: "192.168.9.173"
worker2_hostname: "k8s-worker2"

# Container Runtime Versions
containerd_version: "1.7.14"
runc_version: "1.1.12"
cni_plugins_version: "1.5.0"

# Network Plugin
calico_version: "v3.28.0"

# User Configuration
admin_user: "root"
EOF
```

### Step 3.6: Test Ansible Connectivity

```bash
cd /root/k8s-cluster
ansible all -i inventory.ini -m ping
```

**Expected Output:**
```
k8s-master | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
k8s-worker1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
k8s-worker2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

**✅ Checkpoint:** All three nodes should return "SUCCESS" with "pong".

---

## Phase 4: Node Preparation

### Step 4.1: Set Hostnames on All Nodes

**On Master (192.168.9.182):**
```bash
ssh root@192.168.9.182
hostnamectl set-hostname KubernetesMaster
echo "127.0.0.1 KubernetesMaster" >> /etc/hosts
echo "192.168.9.182 KubernetesMaster" >> /etc/hosts
exit
```

**On Worker1 (192.168.9.171):**
```bash
ssh root@192.168.9.171
hostnamectl set-hostname KubernetesWorker1
echo "127.0.0.1 KubernetesWorker1" >> /etc/hosts
echo "192.168.9.171 KubernetesWorker1" >> /etc/hosts
exit
```

**On Worker2 (192.168.9.173):**
```bash
ssh root@192.168.9.173
hostnamectl set-hostname KubernetesWorker2
echo "127.0.0.1 KubernetesWorker2" >> /etc/hosts
echo "192.168.9.173 KubernetesWorker2" >> /etc/hosts
exit
```

### Step 4.2: Update /etc/hosts on All Nodes

Run this on each node (Master, Worker1, Worker2):

```bash
cat >> /etc/hosts << 'EOF'
192.168.9.182 KubernetesMaster k8s-master
192.168.9.171 KubernetesWorker1 k8s-worker1
192.168.9.173 KubernetesWorker2 k8s-worker2
EOF
```

**Verify:**
```bash
cat /etc/hosts
```

**Expected to see:**
```
192.168.9.182 KubernetesMaster k8s-master
192.168.9.171 KubernetesWorker1 k8s-worker1
192.168.9.173 KubernetesWorker2 k8s-worker2
```

---

## Phase 5: Kubernetes Installation

### Step 5.1: Install Prerequisites on All Nodes

```bash
cd /root/k8s-cluster
ansible-playbook -i inventory.ini 01-common-prerequisites.yml
```

**This playbook will:**
- ✅ Disable swap
- ✅ Load kernel modules (overlay, br_netfilter)
- ✅ Configure network parameters
- ✅ Install containerd v1.7.14
- ✅ Install runc v1.1.12
- ✅ Install CNI plugins v1.5.0
- ✅ Install kubeadm, kubelet, kubectl v1.29.6
- ✅ Configure crictl runtime endpoint

**Expected Duration:** 5-10 minutes

**Expected Output (end of playbook):**
```
PLAY RECAP *********************************************************************
k8s-master       : ok=XX   changed=XX   unreachable=0    failed=0    skipped=0
k8s-worker1      : ok=XX   changed=XX   unreachable=0    failed=0    skipped=0
k8s-worker2      : ok=XX   changed=XX   unreachable=0    failed=0    skipped=0
```

**✅ Checkpoint:** All nodes should show "failed=0".

### Step 5.2: Verify Installation on All Nodes

```bash
# Check from master using Ansible
ansible all -i inventory.ini -a "kubeadm version"
ansible all -i inventory.ini -a "systemctl status containerd" -b
```

**Expected Output:**
```
k8s-master | CHANGED | rc=0 >>
kubeadm version: &version.Info{Major:"1", Minor:"29", GitVersion:"v1.29.6"...}

k8s-worker1 | CHANGED | rc=0 >>
kubeadm version: &version.Info{Major:"1", Minor:"29", GitVersion:"v1.29.6"...}

k8s-worker2 | CHANGED | rc=0 >>
kubeadm version: &version.Info{Major:"1", Minor:"29", GitVersion:"v1.29.6"...}
```

---

## Phase 6: Master Node Initialization

### Step 6.1: SSH to Master Node

```bash
ssh root@192.168.9.182
```

### Step 6.2: Initialize Kubernetes Cluster

```bash
  kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=192.168.9.182 \
  --node-name=kubernetesmaster \
  --cri-socket=unix:///run/containerd/containerd.sock
```

**Expected Duration:** 2-5 minutes

**Expected Output (last few lines):**
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.9.182:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

**⚠️ IMPORTANT:** Copy and save the `kubeadm join` command shown in the output. You'll need it for workers!

### Step 6.3: Configure kubectl for Root User

```bash
# Still on master node
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config
chmod 644 /root/.kube/config
```

### Step 6.4: Verify Master Node Status

```bash
kubectl get nodes
```

**Expected Output:**
```
NAME               STATUS     ROLES           AGE   VERSION
KubernetesMaster   NotReady   control-plane   1m    v1.29.6
```

**Note:** Status is "NotReady" because we haven't installed the CNI plugin yet. This is normal!

### Step 6.5: Check System Pods

```bash
kubectl get pods -n kube-system
```

**Expected Output:**
```
NAME                                       READY   STATUS    RESTARTS   AGE
coredns-76f75df574-xxxxx                   0/1     Pending   0          1m
coredns-76f75df574-yyyyy                   0/1     Pending   0          1m
etcd-kubernetesmaster                      1/1     Running   0          1m
kube-apiserver-kubernetesmaster            1/1     Running   0          1m
kube-controller-manager-kubernetesmaster   1/1     Running   0          1m
kube-proxy-xxxxx                           1/1     Running   0          1m
kube-scheduler-kubernetesmaster            1/1     Running   0          1m
```

**Note:** CoreDNS pods are "Pending" because CNI is not installed yet. This is normal!

### Step 6.6: Save Join Command

```bash
# Generate and save the join command
kubeadm token create --print-join-command > /root/kubeadm-join-command.sh
chmod 700 /root/kubeadm-join-command.sh

# Display the join command
cat /root/kubeadm-join-command.sh
```

**Expected Output:**
```
kubeadm join 192.168.9.182:6443 --token xyz789.abc123def456 --discovery-token-ca-cert-hash sha256:abc123...
```

**✅ Checkpoint:** Master node initialized, kubectl configured, join command saved.

---

## Phase 7: Network Plugin Installation

### Step 7.1: Exit from Master and Return to Control Machine

```bash
# If you're on master node
exit

# You should now be back on the control machine
# (which is also the master node in our case)
cd /root/k8s-cluster
```

### Step 7.2: Install Calico CNI Plugin

```bash
ansible-playbook -i inventory.ini 02-install-calico.yml
```

**Expected Duration:** 2-5 minutes

**Expected Output (end of playbook):**
```
TASK [Display Calico installation summary] ************************************
ok: [k8s-master] => {
    "msg": [
        "==========================================",
        "Calico CNI Installation Complete!",
        "==========================================",
        "Version: v3.28.0",
        "Pod Network CIDR: 192.168.0.0/16",
        ...
    ]
}

PLAY RECAP *********************************************************************
k8s-master       : ok=XX   changed=XX   unreachable=0    failed=0
```

### Step 7.3: Verify Calico Installation

```bash
ssh root@192.168.9.182 "kubectl get pods -n calico-system"
```

**Expected Output (after 2-3 minutes):**
```
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-7c968b5878-xxxxx   1/1     Running   0          2m
calico-node-xxxxx                          1/1     Running   0          2m
calico-typha-yyyyy                         1/1     Running   0          2m
```

### Step 7.4: Verify Master Node is Now Ready

```bash
ssh root@192.168.9.182 "kubectl get nodes"
```

**Expected Output:**
```
NAME               STATUS   ROLES           AGE   VERSION
KubernetesMaster   Ready    control-plane   5m    v1.29.6
```

**✅ Checkpoint:** Master node status changed from "NotReady" to "Ready"!

---

## Phase 8: Worker Nodes Join

### Step 8.1: Get Join Command from Master

```bash
ssh root@192.168.9.182 "cat /root/kubeadm-join-command.sh"
```

**Copy this entire command. It will look like:**
```
kubeadm join 192.168.9.182:6443 --token xyz789.abc123def456 --discovery-token-ca-cert-hash sha256:abc123...
```

### Step 8.2: Join Worker1 to Cluster

```bash
# SSH to Worker1
ssh root@192.168.9.171

# Paste the join command with --cri-socket flag
kubeadm join 192.168.9.182:6443 \
  --token xyz789.abc123def456 \
  --discovery-token-ca-cert-hash sha256:abc123... \
  --cri-socket=unix:///run/containerd/containerd.sock \
  --node-name=KubernetesWorker1
```

**Expected Output:**
```
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

**Exit Worker1:**
```bash
exit
```

### Step 8.3: Join Worker2 to Cluster

```bash
# SSH to Worker2
ssh root@192.168.9.173

# Paste the same join command with --cri-socket flag
kubeadm join 192.168.9.182:6443 \
  --token xyz789.abc123def456 \
  --discovery-token-ca-cert-hash sha256:abc123... \
  --cri-socket=unix:///run/containerd/containerd.sock \
  --node-name=KubernetesWorker2
```

**Expected Output:**
```
This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

**Exit Worker2:**
```bash
exit
```

**✅ Checkpoint:** Both workers have joined the cluster.

---

## Phase 9: Cluster Verification

### Step 9.1: Check All Nodes

```bash
ssh root@192.168.9.182 "kubectl get nodes -o wide"
```

**Expected Output:**
```
NAME                STATUS   ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
KubernetesMaster    Ready    control-plane   10m     v1.29.6   192.168.9.182   <none>        Ubuntu 22.04 LTS     5.15.0-xx-generic   containerd://1.7.14
KubernetesWorker1   Ready    <none>          5m      v1.29.6   192.168.9.171   <none>        Ubuntu 22.04 LTS     5.15.0-xx-generic   containerd://1.7.14
KubernetesWorker2   Ready    <none>          3m      v1.29.6   192.168.9.173   <none>        Ubuntu 22.04 LTS     5.15.0-xx-generic   containerd://1.7.14
```

**All nodes should show "Ready" status!**

### Step 9.2: Check All System Pods

```bash
ssh root@192.168.9.182 "kubectl get pods -A"
```

**Expected Output:**
```
NAMESPACE         NAME                                       READY   STATUS    RESTARTS   AGE
calico-system     calico-kube-controllers-xxxxx              1/1     Running   0          8m
calico-system     calico-node-xxxxx                          1/1     Running   0          8m
calico-system     calico-node-yyyyy                          1/1     Running   0          5m
calico-system     calico-node-zzzzz                          1/1     Running   0          3m
calico-system     calico-typha-xxxxx                         1/1     Running   0          8m
kube-system       coredns-76f75df574-xxxxx                   1/1     Running   0          10m
kube-system       coredns-76f75df574-yyyyy                   1/1     Running   0          10m
kube-system       etcd-kubernetesmaster                      1/1     Running   0          10m
kube-system       kube-apiserver-kubernetesmaster            1/1     Running   0          10m
kube-system       kube-controller-manager-kubernetesmaster   1/1     Running   0          10m
kube-system       kube-proxy-xxxxx                           1/1     Running   0          10m
kube-system       kube-proxy-yyyyy                           1/1     Running   0          5m
kube-system       kube-proxy-zzzzz                           1/1     Running   0          3m
kube-system       kube-scheduler-kubernetesmaster            1/1     Running   0          10m
tigera-operator   tigera-operator-xxxxx                      1/1     Running   0          8m
```

**All pods should be in "Running" status!**

### Step 9.3: Test Pod Deployment

```bash
ssh root@192.168.9.182

# Create a test deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Wait 30 seconds
sleep 30

# Check pods distribution
kubectl get pods -o wide
```

**Expected Output:**
```
NAME                     READY   STATUS    RESTARTS   AGE   IP               NODE                NOMINATED NODE   READINESS GATES
nginx-xxxxx-yyyyy        1/1     Running   0          30s   192.168.xx.xx    KubernetesWorker1   <none>           <none>
nginx-xxxxx-zzzzz        1/1     Running   0          30s   192.168.xx.xx    KubernetesWorker2   <none>           <none>
nginx-xxxxx-aaaaa        1/1     Running   0          30s   192.168.xx.xx    KubernetesWorker1   <none>           <none>
```

**Pods should be distributed across worker nodes!**

### Step 9.4: Test Service and Networking

```bash
# Expose nginx deployment
kubectl expose deployment nginx --port=80 --type=NodePort

# Get service details
kubectl get svc nginx
```

**Expected Output:**
```
NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
nginx   NodePort   10.96.xxx.xxx   <none>        80:xxxxx/TCP   10s
```

### Step 9.5: Test Pod-to-Pod Communication

```bash
# Get pod IPs
kubectl get pods -o wide

# Access one pod from another
POD1=$(kubectl get pods -o jsonpath='{.items[0].metadata.name}')
POD2=$(kubectl get pods -o jsonpath='{.items[1].metadata.name}')

kubectl exec -it $POD1 -- curl -s http://$(kubectl get pod $POD2 -o jsonpath='{.status.podIP}')
```

**Expected Output:**
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

### Step 9.6: Cleanup Test Deployment

```bash
kubectl delete deployment nginx
kubectl delete svc nginx
```

### Step 9.7: Check Cluster Info

```bash
kubectl cluster-info
```

**Expected Output:**
```
Kubernetes control plane is running at https://192.168.9.182:6443
CoreDNS is running at https://192.168.9.182:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

**✅ CONGRATULATIONS! Your Kubernetes cluster is fully operational!**

---

## Troubleshooting

### Issue 0: Ansible Locale Error

**Symptom:**
```
ERROR: Ansible requires the locale encoding to be UTF-8; Detected ISO8859-1.
```

**Solution:**
```bash
# On master node
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
echo 'export LANG=en_US.UTF-8' >> /root/.bashrc
echo 'export LC_ALL=en_US.UTF-8' >> /root/.bashrc

# Verify
locale
ansible --version
```

### Issue 1: SSH Permission Denied (Password Authentication)

**Symptom:**
```
root@192.168.9.182's password: 
Permission denied, please try again.
```

**Solution:**

1. **Check SSH configuration on the target node:**
```bash
# On the node you're trying to access
sudo grep -E "^PermitRootLogin|^PasswordAuthentication" /etc/ssh/sshd_config
```

2. **If not showing "yes", fix it:**
```bash
# On the target node
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

3. **Verify root password is set:**
```bash
# On the target node
sudo passwd root
# Enter new password twice
```

4. **Test SSH again:**
```bash
# From master
ssh root@<target-node-ip> "hostname"
```

### Issue 2: Node Shows "NotReady"

**Check:**
```bash
ssh root@<node-ip> "systemctl status kubelet"
ssh root@<node-ip> "journalctl -u kubelet -n 50"
```

**Fix:**
```bash
ssh root@<node-ip> "systemctl restart kubelet"
```

### Issue 3: Pods Stuck in "Pending"

**Check:**
```bash
kubectl describe pod <pod-name>
kubectl get events --sort-by='.lastTimestamp'
```

**Common causes:**
- CNI not installed (install Calico)
- No worker nodes available (join workers)
- Resource constraints (check with `kubectl describe nodes`)

### Issue 4: Cannot Join Worker Nodes

**Check token validity:**
```bash
# On master
kubeadm token list
```

**Generate new token:**
```bash
# On master
kubeadm token create --print-join-command
```

### Issue 5: Calico Pods Not Starting

**Check:**
```bash
kubectl get pods -n calico-system
kubectl describe pod -n calico-system <pod-name>
```

**Reinstall Calico:**
```bash
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
ansible-playbook -i inventory.ini 02-install-calico.yml
```

### Issue 6: DNS Not Working

**Test DNS:**
```bash
kubectl run test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default
```

**Check CoreDNS:**
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

---

## Summary of Commands

### Quick Status Check
```bash
# From master node
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
```

### Access Cluster from Any Node
```bash
# Copy kubeconfig to other nodes if needed
scp /etc/kubernetes/admin.conf root@192.168.9.171:/root/.kube/config
scp /etc/kubernetes/admin.conf root@192.168.9.173:/root/.kube/config
```

### Generate New Join Command
```bash
# On master
kubeadm token create --print-join-command
```

### View Logs
```bash
# Kubelet logs
journalctl -u kubelet -f

# Pod logs
kubectl logs <pod-name> -n <namespace>

# Events
kubectl get events -A --sort-by='.lastTimestamp'
```

---

## Next Steps

1. **Install Ingress Controller** (nginx-ingress, Traefik)
2. **Set up Persistent Storage** (NFS, Longhorn, Rook-Ceph)
3. **Install Helm** for package management
4. **Set up Monitoring** (Prometheus + Grafana)
5. **Configure RBAC** for user access control
6. **Install Dashboard** (Kubernetes Dashboard)
7. **Set up Backup** (Velero)

---

## Important Files

```
/root/k8s-cluster/
├── inventory.ini                    # Ansible inventory
├── group_vars/all.yml               # Configuration variables
├── 01-common-prerequisites.yml      # Prerequisites playbook
├── 02-install-calico.yml            # Calico installation playbook
└── /root/kubeadm-join-command.sh    # Worker join command (on master)
```

---

## Support

If you encounter issues:
1. Check the troubleshooting section
2. Review logs: `journalctl -u kubelet -f`
3. Check events: `kubectl get events -A`
4. Describe resources: `kubectl describe node <node-name>`

---

**Document Version:** 1.0  
**Date:** February 2026  
**Kubernetes Version:** 1.29.6  
**Author:** K8s Deployment Guide