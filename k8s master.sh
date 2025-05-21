#!/bin/bash

set -e

echo "=== Updating & Installing Kubernetes Master ==="
# Download and execute master setup script
wget https://raw.githubusercontent.com/akshu20791/Deployment-script/main/k8s-master.sh
chmod +x k8s-master.sh
./k8s-master.sh

echo "=== Kubernetes Master Setup Complete ==="
echo "Run the following on the master to get the join command:"
echo ""
echo "    kubeadm token create --print-join-command"
echo ""
echo "Append this to the output: --cri-socket unix:///var/run/cri-dockerd.sock"
