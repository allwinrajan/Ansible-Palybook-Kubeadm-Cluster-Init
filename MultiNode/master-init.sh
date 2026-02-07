#!/bin/bash

# Kubernetes Master Node Initialization Script
# This script initializes the Kubernetes control plane

set -e

# Configuration
MASTER_IP="192.168.9.182"
POD_NETWORK_CIDR="192.168.0.0/16"
SERVICE_CIDR="10.96.0.0/12"
HOSTNAME=$(hostname)

echo "=========================================="
echo "Kubernetes Master Node Initialization"
echo "=========================================="
echo "Master IP: $MASTER_IP"
echo "Pod Network CIDR: $POD_NETWORK_CIDR"
echo "Service CIDR: $SERVICE_CIDR"
echo "Hostname: $HOSTNAME"
echo "=========================================="
echo ""

# Check if cluster is already initialized
if [ -f /etc/kubernetes/admin.conf ]; then
    echo "ERROR: Kubernetes cluster is already initialized!"
    echo "If you want to reinitialize, first run: kubeadm reset -f"
    exit 1
fi

# Initialize the cluster
echo "Initializing Kubernetes cluster..."
echo ""

kubeadm init \
  --pod-network-cidr=$POD_NETWORK_CIDR \
  --service-cidr=$SERVICE_CIDR \
  --apiserver-advertise-address=$MASTER_IP \
  --node-name=$HOSTNAME \
  --cri-socket=unix:///run/containerd/containerd.sock \
  --v=5

echo ""
echo "=========================================="
echo "Cluster Initialization Complete!"
echo "=========================================="

# Set up kubeconfig for root
echo "Setting up kubeconfig for root user..."
mkdir -p /root/.kube
cp -f /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config
chmod 644 /root/.kube/config

# Set up kubeconfig for admin user
ADMIN_USER="administrator"
if [ -d "/home/$ADMIN_USER" ]; then
    echo "Setting up kubeconfig for $ADMIN_USER user..."
    mkdir -p /home/$ADMIN_USER/.kube
    cp -f /etc/kubernetes/admin.conf /home/$ADMIN_USER/.kube/config
    chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.kube
    chmod 644 /home/$ADMIN_USER/.kube/config
fi

# Generate join command
echo ""
echo "Generating join command for worker nodes..."
kubeadm token create --print-join-command > /root/kubeadm-join-command.sh
chmod 700 /root/kubeadm-join-command.sh

echo ""
echo "=========================================="
echo "NEXT STEPS:"
echo "=========================================="
echo "1. Install Calico CNI:"
echo "   ansible-playbook -i inventory.ini 02-install-calico.yml"
echo ""
echo "2. Join worker nodes using the command saved in:"
echo "   /root/kubeadm-join-command.sh"
echo ""
echo "3. View the join command:"
echo "   cat /root/kubeadm-join-command.sh"
echo ""
echo "4. Check cluster status:"
echo "   kubectl get nodes"
echo "   kubectl get pods -A"
echo "=========================================="
