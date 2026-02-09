# Kubernetes Cluster Files - Complete Package
## DNS-Verified Setup for Ubuntu 22.04

---

## 📦 Package Contents

This package contains everything needed to deploy a production-ready 3-node Kubernetes cluster with verified DNS functionality.

### 📄 Main Guide
- **FINAL-K8S-SETUP-GUIDE.md** - Complete step-by-step guide (START HERE!)

### 🔧 Ansible Files
- **inventory.ini** - Ansible inventory file
- **group_vars/all.yml** - Configuration variables
- **01-common-prerequisites.yml** - Prerequisites playbook (REQUIRED - use .yml not .yaml!)
- **02-install-calico.yml** - Calico CNI installation playbook

### 🧪 Testing & Verification
- **verify-dns.sh** - Automated DNS testing script

### 📚 Reference Guides
- **NETWORK-TOPOLOGY.md** - **IMPORTANT!** Network configuration explained
- **DEPLOYMENT-GUIDE.md** - Original deployment guide
- **QUICK-COMMANDS.md** - Quick command reference
- **SSH-SETUP-GUIDE.md** - SSH configuration help
- **TROUBLESHOOTING-GUIDE.md** - Common issues and fixes

### 🔄 Utility Scripts
- **00-reset-cluster.yml** - Reset cluster to clean state
- **master-init.sh** - Alternative master initialization script
- **worker-join.sh** - Alternative worker join script

---

## 🚀 Quick Start

### ⚠️ CRITICAL: Network Configuration
**READ NETWORK-TOPOLOGY.md FIRST!**

Your LAN is 192.168.9.0/24, so we use:
- **Pod Network: 10.244.0.0/16** (NO overlap!)
- **Service Network: 10.96.0.0/12**

Using 192.168.0.0/16 for pods would cause routing conflicts!

### Prerequisites
- 3 fresh Ubuntu 22.04 LTS servers
- Root access to all nodes
- Network connectivity between nodes

### Step 1: Copy Files to Master
```bash
# On your master node (192.168.9.182)
mkdir -p /root/k8s-cluster
cd /root/k8s-cluster

# Copy all files from this package to /root/k8s-cluster/
```

### Step 2: Follow the Main Guide
```bash
# Open and follow step-by-step
cat FINAL-K8S-SETUP-GUIDE.md
```

### Step 3: Run DNS Verification
```bash
# After cluster setup completes
chmod +x verify-dns.sh
./verify-dns.sh
```

---

## 📋 Deployment Phases

### Phase 1-3: Initial Setup
- Enable SSH access
- Install Ansible
- Configure SSH keys

### Phase 4: Hostnames (CRITICAL!)
- Set proper lowercase hostnames
- Update /etc/hosts on all nodes

### Phase 5: Install Kubernetes
```bash
ansible-playbook -i inventory.ini 01-common-prerequisites.yml
```

### Phase 6: Initialize Master
```bash
kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=192.168.9.182 \
  --node-name=kubernetesmaster \
  --cri-socket=unix:///run/containerd/containerd.sock
```

### Phase 7: Install Calico
```bash
ansible-playbook -i inventory.ini 02-install-calico.yml
```

### Phase 8: Join Workers
```bash
# Use command from kubeadm init output
```

### Phase 9: Verify DNS
```bash
./verify-dns.sh
```

---

## ⚠️ Critical Points for DNS

### 1. Hostnames MUST be lowercase
✅ **Correct:** kubernetesmaster, kubernetesworker1, kubernetesworker2
❌ **Wrong:** KubernetesMaster, kubernetes-master, Kubernetes_Master

### 2. Use .yml extension (not .yaml)
✅ **Correct:** `ansible-playbook -i inventory.ini 01-common-prerequisites.yml`
❌ **Wrong:** `ansible-playbook -i inventory.ini 01-common-prerequisites.yaml`

### 3. Node names in kubeadm init must match hostname
```bash
# Get hostname first
hostname
# Output: kubernetesmaster

# Use exact same name in kubeadm init
kubeadm init --node-name=kubernetesmaster
```

### 4. Wait for Calico pods before joining workers
```bash
# After installing Calico, wait for pods
kubectl get pods -n calico-system
# All must show Running before joining workers
```

### 5. Verify /etc/hosts on all nodes
```bash
# Must contain all three nodes
cat /etc/hosts | grep kubernetes
# Should show:
# 192.168.9.182 kubernetesmaster
# 192.168.9.171 kubernetesworker1
# 192.168.9.173 kubernetesworker2
```

---

## 🧪 DNS Verification Tests

After setup, these must all pass:

```bash
# 1. CoreDNS running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Internal DNS
kubectl run test --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default

# 3. External DNS
kubectl run test --image=busybox:1.28 --rm -it --restart=Never -- nslookup google.com

# 4. apt update works
kubectl run test --image=ubuntu:22.04 --rm -it --restart=Never -- apt update

# 5. Service discovery
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80
kubectl run test --image=curlimages/curl --rm -it --restart=Never -- curl nginx
kubectl delete deployment nginx
kubectl delete svc nginx
```

**Or use the automated script:**
```bash
./verify-dns.sh
```

---

## 🔧 File Locations After Setup

```
/root/k8s-cluster/                          # Main directory
├── FINAL-K8S-SETUP-GUIDE.md                # Main guide
├── inventory.ini                           # Ansible inventory
├── group_vars/all.yml                      # Variables
├── 01-common-prerequisites.yml             # Prerequisites
├── 02-install-calico.yml                   # Calico CNI
├── verify-dns.sh                           # DNS test script
└── ...other files...

/root/.kube/config                          # kubectl config
/root/kubeadm-join-command.sh               # Join command
```

---

## 📊 Expected Timeline

| Phase | Task | Duration |
|-------|------|----------|
| 1-3 | SSH & Ansible Setup | 10-15 min |
| 4 | Hostname Configuration | 5 min |
| 5 | Install Prerequisites | 5-10 min |
| 6 | Initialize Master | 2-5 min |
| 7 | Install Calico | 2-5 min |
| 8 | Join Workers | 5 min |
| 9 | DNS Verification | 2 min |
| **Total** | **Complete Setup** | **30-45 min** |

---

## 🎯 Success Criteria

Your cluster is ready when:

✅ All 3 nodes show STATUS: Ready
✅ All system pods show STATUS: Running
✅ CoreDNS pods are 1/1 Running
✅ `./verify-dns.sh` shows ALL TESTS PASSED
✅ apt update works inside pods
✅ Pods can communicate with each other
✅ Pods can access internet

---

## 🚨 Common Issues

### Issue: DNS not working in pods

**Solution:**
```bash
# 1. Check hostnames are lowercase
hostname  # Should be: kubernetesmaster (lowercase)

# 2. Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system

# 3. Check Calico
kubectl get pods -n calico-system
```

### Issue: apt update fails in pods

**Cause:** DNS not resolving or no internet access

**Solution:**
```bash
# Test DNS first
kubectl run test --image=busybox:1.28 --rm -it --restart=Never -- nslookup google.com

# If DNS works but apt fails, check network
kubectl run test --image=busybox:1.28 --rm -it --restart=Never -- ping -c 2 8.8.8.8
```

### Issue: Worker nodes NotReady

**Solution:**
```bash
# Check Calico on worker
ssh root@192.168.9.171 "systemctl restart kubelet"

# Check logs
ssh root@192.168.9.171 "journalctl -u kubelet -n 50"
```

---

## 🔄 Reset and Start Over

If you need to completely reset:

```bash
# On all nodes
ansible-playbook -i inventory.ini 00-reset-cluster.yml

# Then start from Phase 6 (kubeadm init)
```

---

## 📞 Support

If you encounter issues:

1. Check the TROUBLESHOOTING-GUIDE.md
2. Run ./verify-dns.sh to identify problem
3. Check logs: `kubectl logs -n kube-system -l k8s-app=kube-dns`
4. Verify: `kubectl get events -A --sort-by='.lastTimestamp'`

---

## ✅ Verified Configuration

This setup has been tested with:
- ✅ Ubuntu 22.04.5 LTS
- ✅ Kubernetes v1.29.6
- ✅ containerd v1.7.14
- ✅ Calico v3.28.0
- ✅ CoreDNS functional
- ✅ DNS resolution in pods
- ✅ apt/yum update works
- ✅ Internet access from pods

---

**Package Version:** 2.0 - DNS Verified
**Last Updated:** February 2026
**Maintainer:** K8s Setup Guide Team