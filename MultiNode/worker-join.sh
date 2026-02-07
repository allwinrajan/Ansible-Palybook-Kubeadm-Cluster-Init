#!/bin/bash

# Kubernetes Worker Node Join Script
# This script joins a worker node to the Kubernetes cluster

set -e

echo "=========================================="
echo "Kubernetes Worker Node Join"
echo "=========================================="
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "=========================================="
echo ""

# Check if already joined
if [ -f /etc/kubernetes/kubelet.conf ]; then
    echo "ERROR: This node is already part of a Kubernetes cluster!"
    echo "If you want to rejoin, first run: kubeadm reset -f"
    exit 1
fi

# Check if join command is provided
if [ -z "$1" ]; then
    echo "ERROR: Join command not provided!"
    echo ""
    echo "Usage: $0 '<join-command>'"
    echo ""
    echo "Example:"
    echo "  $0 'kubeadm join 192.168.9.182:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx'"
    echo ""
    echo "To get the join command from master node, run:"
    echo "  ssh administrator@192.168.9.182 'cat /root/kubeadm-join-command.sh'"
    exit 1
fi

# Execute join command
echo "Joining cluster..."
echo ""

# Add CRI socket to join command if not present
JOIN_CMD="$1"
if [[ ! "$JOIN_CMD" =~ "--cri-socket" ]]; then
    JOIN_CMD="$JOIN_CMD --cri-socket=unix:///run/containerd/containerd.sock"
fi

eval $JOIN_CMD

echo ""
echo "=========================================="
echo "Worker Node Joined Successfully!"
echo "=========================================="
echo ""
echo "Verify on master node:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "=========================================="
