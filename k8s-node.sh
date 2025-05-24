#!/bin/bash

set -e

echo "=== Updating & Installing Kubernetes Node ==="


# Download and execute node setup script
wget https://raw.githubusercontent.com/akshu20791/Deployment-script/main/k8s-nodes.sh
chmod +x k8s-nodes.sh
./k8s-nodes.sh

# Load kernel modules required for kube-proxy and networking
sudo modprobe br_netfilter
sudo sh -c "echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables"
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

echo "=== Node Setup Complete ==="
echo "Run the kubeadm join command here when you get it from the master"
