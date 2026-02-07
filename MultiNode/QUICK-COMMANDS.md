# Kubernetes Cluster Quick Commands

## Deployment Commands (Execute in Order)

```bash
# 1. Reset existing cluster
ansible-playbook -i inventory.ini 00-reset-cluster.yml

# 2. Install prerequisites on all nodes (master + workers)
ansible-playbook -i inventory.ini 01-common-prerequisites.yml

# 3. Initialize master (manual - SSH to master)
ssh administrator@192.168.9.182
sudo bash /tmp/master-init.sh

# 4. Install Calico CNI
ansible-playbook -i inventory.ini 02-install-calico.yml

# 5. Get join command from master
ssh administrator@192.168.9.182 "sudo cat /root/kubeadm-join-command.sh"

# 6. Join worker1 (manual - SSH to worker1)
ssh administrator@192.168.9.171
sudo bash /tmp/worker-join.sh "kubeadm join 192.168.9.182:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx"

# 7. Join worker2 (manual - SSH to worker2)
ssh administrator@192.168.9.173
sudo bash /tmp/worker-join.sh "kubeadm join 192.168.9.182:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx"

# 8. Verify cluster
ssh administrator@192.168.9.182 "kubectl get nodes"
```

## Cluster Management Commands

```bash
# View cluster status
kubectl get nodes -o wide
kubectl get pods -A
kubectl cluster-info

# Generate new join command (if expired)
sudo kubeadm token create --print-join-command

# View join tokens
sudo kubeadm token list

# Check component health
kubectl get componentstatuses
kubectl get pods -n kube-system
kubectl get pods -n calico-system

# View cluster events
kubectl get events -A --sort-by='.lastTimestamp'

# Node operations
kubectl cordon <node-name>                    # Mark unschedulable
kubectl uncordon <node-name>                  # Mark schedulable
kubectl drain <node-name> --ignore-daemonsets # Evict pods
kubectl delete node <node-name>               # Remove node
```

## Troubleshooting Commands

```bash
# Check kubelet on any node
sudo systemctl status kubelet
sudo journalctl -u kubelet -f

# Check containerd
sudo systemctl status containerd
sudo crictl ps
sudo crictl pods

# Check pod logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous  # Previous container

# Describe resources
kubectl describe node <node-name>
kubectl describe pod <pod-name> -n <namespace>

# Check network
kubectl get pods -n calico-system
kubectl exec -it <pod-name> -- /bin/sh
ping <other-pod-ip>

# Check certificates
sudo kubeadm certs check-expiration

# View kubeconfig
cat ~/.kube/config
```

## Reset Commands

```bash
# Reset single node
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo rm -rf ~/.kube
sudo systemctl restart containerd

# Reset entire cluster
ansible-playbook -i inventory.ini 00-reset-cluster.yml
```

## File Locations

```bash
# Kubernetes configs
/etc/kubernetes/admin.conf           # Main kubeconfig
/etc/kubernetes/manifests/           # Static pod manifests
~/.kube/config                       # User kubeconfig

# Logs
/var/log/pods/                       # Pod logs
/var/log/containers/                 # Container logs
journalctl -u kubelet                # Kubelet logs

# Runtime
/etc/containerd/config.toml          # Containerd config
/etc/crictl.yaml                     # CRI config
/run/containerd/containerd.sock      # Containerd socket

# Join command
/root/kubeadm-join-command.sh        # Saved join command
```

## Node IP Addresses

```bash
Master:  192.168.9.182
Worker1: 192.168.9.171
Worker2: 192.168.9.173
```

## Test Application Deployment

```bash
# Deploy nginx
kubectl create deployment nginx --image=nginx --replicas=3
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get svc nginx
kubectl get pods -o wide

# Test connectivity
kubectl run test --image=busybox --rm -it --restart=Never -- wget -O- http://nginx

# Cleanup
kubectl delete deployment nginx
kubectl delete svc nginx
```
