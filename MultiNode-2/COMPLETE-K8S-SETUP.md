# Kubernetes Cluster - Complete Setup Guide
## Ubuntu 22.04 | 3 Nodes | All Operations from Master

**EVERYTHING runs from Master Node - No jump server needed**

---

## 🎯 Infrastructure

```
┌─────────────────────────────────────────────────────┐
│ Master:  192.168.9.182  → kubernetesmaster         │
│ Worker1: 192.168.9.171  → kubernetesworker1        │
│ Worker2: 192.168.9.173  → kubernetesworker2        │
├─────────────────────────────────────────────────────┤
│ LAN:      192.168.9.0/24    (Physical)             │
│ Pods:     10.244.0.0/16     (Virtual - No overlap!)│
│ Services: 10.96.0.0/12      (Virtual)              │
└─────────────────────────────────────────────────────┘
```

---

## 📁 File Structure You'll Create

```
/root/k8s-cluster/
├── inventory.ini                    # Ansible inventory
├── group_vars/
│   └── all.yml                      # Configuration variables
├── 01-fix-dns-hosts.yml             # Fix DNS on all nodes
├── 02-install-prerequisites.yml     # Install K8s components
└── 03-install-calico.yml            # Install Calico CNI
```

---

## ⚡ COMPLETE STEP-BY-STEP GUIDE

### 🔷 PHASE 1: FIX DNS ON ALL NODES (CRITICAL!)

**Step 1.1 - Fix DNS on Master First**

You're already on master. Run:

```bash
# Become root if not already
sudo su -

# Fix DNS resolver
cat > /etc/resolv.conf << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 127.0.0.53
search .
EOF

# Make it immutable (prevent systemd-resolved from overwriting)
chattr +i /etc/resolv.conf

# Test DNS
ping -c 2 google.com
apt update
```

**Expected:** Google ping works, apt update works

**Step 1.2 - Fix DNS on Worker1**

```bash
# From master, SSH to worker1
ssh administrator@192.168.9.171

# Become root
sudo su -

# Fix DNS
cat > /etc/resolv.conf << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 127.0.0.53
search .
EOF

chattr +i /etc/resolv.conf

# Test
ping -c 2 google.com

# Exit back to master
exit
exit
```

**Step 1.3 - Fix DNS on Worker2**

```bash
# From master, SSH to worker2
ssh administrator@192.168.9.173

# Become root
sudo su -

# Fix DNS
cat > /etc/resolv.conf << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 127.0.0.53
search .
EOF

chattr +i /etc/resolv.conf

# Test
ping -c 2 google.com

# Exit back to master
exit
exit
```

---

### 🔷 PHASE 2: ENABLE ROOT SSH ACCESS

**Step 2.1 - Master (you're here)**

```bash
# On master as root
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Set root password if not set
passwd root
```

**Step 2.2 - Worker1**

```bash
ssh administrator@192.168.9.171 "sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && sudo systemctl restart sshd && echo 'SSH configured on Worker1'"

# Set root password on worker1
ssh administrator@192.168.9.171
sudo passwd root
exit
```

**Step 2.3 - Worker2**

```bash
ssh administrator@192.168.9.173 "sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && sudo systemctl restart sshd && echo 'SSH configured on Worker2'"

# Set root password on worker2
ssh administrator@192.168.9.173
sudo passwd root
exit
```

---

### 🔷 PHASE 3: SSH KEY DISTRIBUTION

**Step 3.1 - Generate SSH key on Master**

```bash
# On master as root
ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""
```

**Step 3.2 - Copy keys to all nodes**

```bash
# Copy to master itself
ssh-copy-id root@192.168.9.182

# Copy to worker1
ssh-copy-id root@192.168.9.171

# Copy to worker2
ssh-copy-id root@192.168.9.173
```

**Step 3.3 - Test passwordless SSH**

```bash
ssh root@192.168.9.182 "hostname"
ssh root@192.168.9.171 "hostname"
ssh root@192.168.9.173 "hostname"
```

✅ **Checkpoint:** All return hostnames without asking for password

---

### 🔷 PHASE 4: INSTALL ANSIBLE & FIX LOCALE

**Step 4.1 - Fix locale**

```bash
# On master
locale-gen en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
echo 'export LANG=en_US.UTF-8' >> /root/.bashrc
echo 'export LC_ALL=en_US.UTF-8' >> /root/.bashrc
```

**Step 4.2 - Install Ansible**

```bash
apt update
apt install -y software-properties-common
add-apt-repository -y ppa:ansible/ansible
apt update
apt install -y ansible

# Verify
ansible --version
```

---

### 🔷 PHASE 5: CREATE ANSIBLE FILES

**Step 5.1 - Create project directory**

```bash
mkdir -p /root/k8s-cluster/group_vars
cd /root/k8s-cluster
```

**Step 5.2 - Create inventory.ini**

```bash
cat > /root/k8s-cluster/inventory.ini << 'EOF'
[all:vars]
ansible_user=root
ansible_python_interpreter=/usr/bin/python3

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

**Step 5.3 - Create group_vars/all.yml**

```bash
cat > /root/k8s-cluster/group_vars/all.yml << 'EOF'
---
# Kubernetes Cluster Configuration
kubernetes_version: "1.29.6-1.1"
pod_network_cidr: "10.244.0.0/16"
service_cidr: "10.96.0.0/12"

# Node Configuration
master_ip: "192.168.9.182"
master_hostname: "kubernetesmaster"

worker1_ip: "192.168.9.171"
worker1_hostname: "kubernetesworker1"

worker2_ip: "192.168.9.173"
worker2_hostname: "kubernetesworker2"

# Container Runtime
containerd_version: "1.7.14"
runc_version: "1.1.12"
cni_plugins_version: "1.5.0"

# Network Plugin
calico_version: "v3.28.0"

# DNS Settings
dns_servers:
  - "8.8.8.8"
  - "8.8.4.4"
  - "127.0.0.53"
EOF
```

**Step 5.4 - Test Ansible connectivity**

```bash
cd /root/k8s-cluster
ansible all -i inventory.ini -m ping
```

✅ **Checkpoint:** All nodes return "pong"

---

### 🔷 PHASE 6: CREATE PLAYBOOK 1 - FIX DNS & HOSTNAMES

**Step 6.1 - Create 01-fix-dns-hosts.yml**

```bash
cat > /root/k8s-cluster/01-fix-dns-hosts.yml << 'EOF'
---
- name: Fix DNS and Hostnames on All Nodes
  hosts: cluster
  become: yes
  gather_facts: yes

  tasks:
    - name: Set proper hostname on master
      hostname:
        name: "{{ master_hostname }}"
      when: inventory_hostname == 'k8s-master'

    - name: Set proper hostname on worker1
      hostname:
        name: "{{ worker1_hostname }}"
      when: inventory_hostname == 'k8s-worker1'

    - name: Set proper hostname on worker2
      hostname:
        name: "{{ worker2_hostname }}"
      when: inventory_hostname == 'k8s-worker2'

    - name: Update /etc/hostname
      copy:
        content: |
          {{ master_hostname if inventory_hostname == 'k8s-master' else (worker1_hostname if inventory_hostname == 'k8s-worker1' else worker2_hostname) }}
        dest: /etc/hostname

    - name: Remove immutable flag from /etc/resolv.conf if exists
      command: chattr -i /etc/resolv.conf
      ignore_errors: yes

    - name: Configure DNS resolvers
      copy:
        content: |
          nameserver 8.8.8.8
          nameserver 8.8.4.4
          nameserver 127.0.0.53
          search .
        dest: /etc/resolv.conf
        mode: '0644'

    - name: Make resolv.conf immutable
      command: chattr +i /etc/resolv.conf

    - name: Update /etc/hosts with all nodes
      blockinfile:
        path: /etc/hosts
        marker: "# {mark} ANSIBLE MANAGED K8S HOSTS"
        block: |
          {{ master_ip }} {{ master_hostname }}
          {{ worker1_ip }} {{ worker1_hostname }}
          {{ worker2_ip }} {{ worker2_hostname }}

    - name: Test DNS resolution
      command: ping -c 2 google.com
      register: dns_test
      changed_when: false
      failed_when: dns_test.rc != 0

    - name: Display hostname
      debug:
        msg: "Hostname set to: {{ ansible_hostname }}"
EOF
```

**Step 6.2 - Run the playbook**

```bash
cd /root/k8s-cluster
ansible-playbook -i inventory.ini 01-fix-dns-hosts.yml
```

**Expected:** All tasks green/ok, no failed

✅ **Checkpoint:** DNS and hostnames configured on all nodes

---

### 🔷 PHASE 7: CREATE PLAYBOOK 2 - INSTALL KUBERNETES

**Step 7.1 - Create 02-install-prerequisites.yml**

```bash
cat > /root/k8s-cluster/02-install-prerequisites.yml << 'EOF'
---
- name: Install Kubernetes Prerequisites
  hosts: cluster
  become: yes
  gather_facts: yes

  tasks:
    # Clean APT locks
    - name: Kill apt processes
      shell: killall -9 apt-get apt dpkg 2>/dev/null || true
      changed_when: false
      ignore_errors: yes

    - name: Remove apt locks
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - /var/lib/apt/lists/lock
        - /var/cache/apt/archives/lock
        - /var/lib/dpkg/lock
        - /var/lib/dpkg/lock-frontend
      ignore_errors: yes

    - name: Configure dpkg
      command: dpkg --configure -a
      changed_when: false
      ignore_errors: yes

    # Disable swap
    - name: Disable swap
      command: swapoff -a
      changed_when: false

    - name: Remove swap from fstab
      replace:
        path: /etc/fstab
        regexp: '^([^#].*?\sswap\s+.*)$'
        replace: '#\1'

    # Load kernel modules
    - name: Load kernel modules
      copy:
        dest: /etc/modules-load.d/k8s.conf
        content: |
          overlay
          br_netfilter

    - name: Load overlay module
      modprobe:
        name: overlay
        state: present

    - name: Load br_netfilter module
      modprobe:
        name: br_netfilter
        state: present

    # Configure sysctl
    - name: Configure sysctl for Kubernetes
      copy:
        dest: /etc/sysctl.d/k8s.conf
        content: |
          net.bridge.bridge-nf-call-iptables  = 1
          net.bridge.bridge-nf-call-ip6tables = 1
          net.ipv4.ip_forward                 = 1

    - name: Apply sysctl
      command: sysctl --system
      changed_when: false

    # Install containerd
    - name: Download containerd
      get_url:
        url: "https://github.com/containerd/containerd/releases/download/v{{ containerd_version }}/containerd-{{ containerd_version }}-linux-amd64.tar.gz"
        dest: /tmp/containerd.tar.gz
      when: not (ansible_local.containerd.installed | default(false))

    - name: Extract containerd
      unarchive:
        src: /tmp/containerd.tar.gz
        dest: /usr/local
        remote_src: yes
      when: not (ansible_local.containerd.installed | default(false))

    - name: Download containerd service
      get_url:
        url: https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
        dest: /tmp/containerd.service

    - name: Create systemd directory
      file:
        path: /usr/local/lib/systemd/system
        state: directory

    - name: Install containerd service
      copy:
        src: /tmp/containerd.service
        dest: /usr/local/lib/systemd/system/containerd.service
        remote_src: yes

    - name: Create containerd config directory
      file:
        path: /etc/containerd
        state: directory

    - name: Generate containerd config
      shell: containerd config default > /etc/containerd/config.toml
      args:
        creates: /etc/containerd/config.toml

    - name: Enable SystemdCgroup
      replace:
        path: /etc/containerd/config.toml
        regexp: 'SystemdCgroup = false'
        replace: 'SystemdCgroup = true'

    - name: Start containerd
      systemd:
        name: containerd
        state: restarted
        enabled: yes
        daemon_reload: yes

    # Install runc
    - name: Download runc
      get_url:
        url: "https://github.com/opencontainers/runc/releases/download/v{{ runc_version }}/runc.amd64"
        dest: /usr/local/sbin/runc
        mode: '0755'

    # Install CNI plugins
    - name: Download CNI plugins
      get_url:
        url: "https://github.com/containernetworking/plugins/releases/download/v{{ cni_plugins_version }}/cni-plugins-linux-amd64-v{{ cni_plugins_version }}.tgz"
        dest: /tmp/cni-plugins.tgz

    - name: Create CNI directory
      file:
        path: /opt/cni/bin
        state: directory

    - name: Extract CNI plugins
      unarchive:
        src: /tmp/cni-plugins.tgz
        dest: /opt/cni/bin
        remote_src: yes

    # Install Kubernetes packages
    - name: Install dependencies
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - gpg
        state: present
        update_cache: yes

    - name: Create keyrings directory
      file:
        path: /etc/apt/keyrings
        state: directory
        mode: '0755'

    - name: Add Kubernetes GPG key
      shell: curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      args:
        creates: /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    - name: Add Kubernetes repository
      copy:
        dest: /etc/apt/sources.list.d/kubernetes.list
        content: "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /"

    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install Kubernetes packages
      apt:
        name:
          - "kubelet={{ kubernetes_version }}"
          - "kubeadm={{ kubernetes_version }}"
          - "kubectl={{ kubernetes_version }}"
        state: present
        allow_downgrade: yes

    - name: Hold Kubernetes packages
      dpkg_selections:
        name: "{{ item }}"
        selection: hold
      loop:
        - kubelet
        - kubeadm
        - kubectl

    - name: Configure crictl
      shell: crictl config runtime-endpoint unix:///run/containerd/containerd.sock
      args:
        creates: /etc/crictl.yaml

    - name: Enable kubelet
      systemd:
        name: kubelet
        enabled: yes

    - name: Display completion
      debug:
        msg: "Node {{ inventory_hostname }} ready for Kubernetes!"
EOF
```

**Step 7.2 - Run the playbook**

```bash
cd /root/k8s-cluster
ansible-playbook -i inventory.ini 02-install-prerequisites.yml
```

**Expected Duration:** 5-10 minutes

✅ **Checkpoint:** All nodes have Kubernetes installed

---

### 🔷 PHASE 8: INITIALIZE MASTER NODE

**Step 8.1 - Initialize cluster**

```bash
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=192.168.9.182 \
  --node-name=kubernetesmaster \
  --cri-socket=unix:///run/containerd/containerd.sock \
  --v=5
```

**⚠️ SAVE THE JOIN COMMAND!**

**Step 8.2 - Configure kubectl**

```bash
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chmod 600 /root/.kube/config
```

**Step 8.3 - Save join command**

```bash
kubeadm token create --print-join-command > /root/kubeadm-join-command.sh
chmod 700 /root/kubeadm-join-command.sh
cat /root/kubeadm-join-command.sh
```

**Step 8.4 - Check master**

```bash
kubectl get nodes
# Expected: kubernetesmaster NotReady (normal - no CNI yet)

kubectl get pods -n kube-system
# Expected: coredns Pending (normal - no CNI yet)
```

✅ **Checkpoint:** Master initialized, coredns pending

---

### 🔷 PHASE 9: INSTALL CALICO CNI

**Step 9.1 - Create 03-install-calico.yml**

```bash
cat > /root/k8s-cluster/03-install-calico.yml << 'EOF'
---
- name: Install Calico CNI
  hosts: master
  become: yes
  gather_facts: no

  tasks:
    - name: Wait for API server
      wait_for:
        host: "{{ master_ip }}"
        port: 6443
        timeout: 300

    - name: Install Tigera operator
      shell: kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/{{ calico_version }}/manifests/tigera-operator.yaml
      register: operator_result
      failed_when: false

    - name: Wait for operator
      pause:
        seconds: 15

    - name: Download custom resources
      get_url:
        url: https://raw.githubusercontent.com/projectcalico/calico/{{ calico_version }}/manifests/custom-resources.yaml
        dest: /tmp/calico-custom-resources.yaml

    - name: Update CIDR in custom resources
      replace:
        path: /tmp/calico-custom-resources.yaml
        regexp: '192\.168\.0\.0/16'
        replace: '{{ pod_network_cidr }}'

    - name: Apply custom resources
      command: kubectl apply -f /tmp/calico-custom-resources.yaml

    - name: Wait for calico-system namespace
      shell: kubectl get namespace calico-system
      register: ns_check
      until: ns_check.rc == 0
      retries: 30
      delay: 10

    - name: Wait for Calico pods
      shell: kubectl get pods -n calico-system --no-headers | grep -v Running | wc -l
      register: pods_check
      until: pods_check.stdout == "0"
      retries: 40
      delay: 10

    - name: Display Calico status
      shell: kubectl get pods -n calico-system
      register: calico_pods

    - name: Show Calico pods
      debug:
        var: calico_pods.stdout_lines

    - name: Wait for nodes to be Ready
      shell: kubectl get nodes --no-headers | grep NotReady | wc -l
      register: nodes_check
      until: nodes_check.stdout == "0"
      retries: 30
      delay: 10

    - name: Display node status
      shell: kubectl get nodes
      register: nodes_status

    - name: Show nodes
      debug:
        var: nodes_status.stdout_lines
EOF
```

**Step 9.2 - Run Calico playbook**

```bash
cd /root/k8s-cluster
ansible-playbook -i inventory.ini 03-install-calico.yml
```

**Expected Duration:** 2-5 minutes

**Step 9.3 - Verify master is Ready**

```bash
kubectl get nodes
# Expected: kubernetesmaster Ready

kubectl get pods -n calico-system
# Expected: All Running

kubectl get pods -n kube-system -l k8s-app=kube-dns
# Expected: coredns Running
```

✅ **Checkpoint:** Master Ready, CoreDNS Running

---

### 🔷 PHASE 10: JOIN WORKER NODES

**Step 10.1 - Join Worker1**

```bash
# Get join command
JOIN_CMD=$(cat /root/kubeadm-join-command.sh)

# Execute on worker1
ssh root@192.168.9.171 "$JOIN_CMD"
```

**Expected:** "This node has joined the cluster"

**Step 10.2 - Join Worker2**

```bash
# Execute on worker2
ssh root@192.168.9.173 "$JOIN_CMD"
```

**Expected:** "This node has joined the cluster"

**Step 10.3 - Verify all nodes**

```bash
kubectl get nodes
# Wait 1-2 minutes for all to become Ready
```

**Expected:**
```
NAME                STATUS   ROLES           AGE   VERSION
kubernetesmaster    Ready    control-plane   15m   v1.29.6
kubernetesworker1   Ready    <none>          3m    v1.29.6
kubernetesworker2   Ready    <none>          2m    v1.29.6
```

✅ **Checkpoint:** All 3 nodes Ready!

---

### 🔷 PHASE 11: DNS VERIFICATION

**Test 1: CoreDNS Running**

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

**Expected:** 2 coredns pods Running

**Test 2: Internal DNS**

```bash
kubectl run test-dns --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default
```

**Expected:** Should resolve to 10.96.0.1

**Test 3: External DNS**

```bash
kubectl run test-ext --image=busybox:1.28 --rm -it --restart=Never -- nslookup google.com
```

**Expected:** Should resolve google.com

**Test 4: apt update in pod (YOUR CRITICAL TEST!)**

```bash
kubectl run test-apt --image=ubuntu:22.04 --rm -it --restart=Never -- bash -c "apt update"
```

**Expected:** Package lists download successfully!

**Test 5: Create nginx and test**

```bash
# Deploy nginx
kubectl create deployment nginx --image=nginx:alpine --replicas=2

# Wait for pods
kubectl wait --for=condition=ready pod -l app=nginx --timeout=60s

# Expose service
kubectl expose deployment nginx --port=80 --name=nginx-svc

# Test service DNS
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl nginx-svc.default.svc.cluster.local

# Cleanup
kubectl delete deployment nginx
kubectl delete svc nginx-svc
```

**Expected:** All tests pass!

✅ **Checkpoint:** DNS working perfectly!

---

## 📊 QUICK REFERENCE

### File Structure Created

```
/root/k8s-cluster/
├── inventory.ini
├── group_vars/
│   └── all.yml
├── 01-fix-dns-hosts.yml
├── 02-install-prerequisites.yml
└── 03-install-calico.yml

/root/
├── .kube/config
└── kubeadm-join-command.sh
```

### Execution Order

```bash
# Phase 1-5: Manual setup
# Phase 6:
ansible-playbook -i inventory.ini 01-fix-dns-hosts.yml

# Phase 7:
ansible-playbook -i inventory.ini 02-install-prerequisites.yml

# Phase 8:
kubeadm init --pod-network-cidr=10.244.0.0/16 ...
mkdir -p /root/.kube && cp /etc/kubernetes/admin.conf /root/.kube/config

# Phase 9:
ansible-playbook -i inventory.ini 03-install-calico.yml

# Phase 10:
ssh root@192.168.9.171 "$(cat /root/kubeadm-join-command.sh)"
ssh root@192.168.9.173 "$(cat /root/kubeadm-join-command.sh)"

# Phase 11:
kubectl run test-apt --image=ubuntu:22.04 --rm -it --restart=Never -- apt update
```

### Useful Commands

```bash
# Check cluster status
kubectl get nodes -o wide
kubectl get pods -A
kubectl cluster-info

# Check DNS
kubectl get svc -n kube-system kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Check Calico
kubectl get pods -n calico-system

# Generate new join token
kubeadm token create --print-join-command

# View logs
journalctl -u kubelet -f
kubectl describe node kubernetesmaster
```

---

## 🎯 SUCCESS CRITERIA

Your cluster is ready when:

- ✅ All 3 nodes show STATUS: Ready
- ✅ All pods show STATUS: Running
- ✅ CoreDNS pods are 1/1 Running
- ✅ apt update works inside Ubuntu pods
- ✅ External DNS resolution works
- ✅ Service discovery works

---

## 🚨 CRITICAL POINTS

1. **DNS on hosts MUST be fixed first** - Add nameserver 8.8.8.8
2. **Hostnames MUST be lowercase** - kubernetesmaster (not KubernetesMaster)
3. **Pod network is 10.244.0.0/16** - Does NOT overlap with 192.168.9.0/24
4. **Use .yml extension** - Not .yaml
5. **All operations from master** - No jump server needed

---

**Setup Time:** ~30-40 minutes
**Version:** 3.0 - Complete with DNS fixes
**Date:** February 2026
