#!/bin/bash

set -x

### TODO - differentiate between the first master, other masters and regular workers

# Stop the kube-controller-manager static pod by moving its config away
#sudo mv /etc/kubernetes/manifests/kube-controller-manager.yaml /etc/kubernetes/

# Edit the unused file and add the --cloud-provider=external flag
#sudo sed -i /'- kube-controller-manager'/a'\ \ \ \ - --cloud-provider=external' /etc/kubernetes/kube-controller-manager.yaml

# Move the file back in order for kube-controller-manager to re-launch with the flag
#sudo mv /etc/kubernetes/kube-controller-manager.yaml /etc/kubernetes/manifests/

# Dynamically edit the kube-apiserver static pod to run with the same flag by edit its yaml
#sudo sed -i /'- kube-apiserver'/a'\ \ \ \ - --cloud-provider=external' /etc/kubernetes/manifests/kube-apiserver.yaml

# Get the instance id from the metadata service
export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Change the kubelet service configuration to use the new settings
sudo sed -i s,config.yaml,"config.yaml --cloud-provider=external --provider-id=aws:///symphony/$INSTANCE_ID", /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Restart kubelet with the new config
sudo systemctl daemon-reload
sudo systemctl restart kubelet --no-block

