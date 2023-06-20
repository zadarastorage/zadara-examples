#!/bin/bash

# set kubelet-arg
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "kubelet-arg: provider-id=aws:///symphony/$instance_id" >> /etc/rancher/rke2/config.yaml

# start RKE2 node
if [ "$INSTALL_RKE2_TYPE" == "agent" ]; then
    systemctl enable rke2-agent
    systemctl start rke2-agent --no-block
else
    systemctl enable rke2-server
    systemctl start rke2-server --no-block
fi