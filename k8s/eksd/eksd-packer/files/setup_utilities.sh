#!/bin/bash

export NEEDRESTART_MODE=a
export DEBIAN_FRONTEND=noninteractive

# AWS CLI
sudo apt-get install unzip -y
sudo curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'
sudo unzip -o awscliv2.zip
sudo ./aws/install --update
sudo rm ./awscliv2.zip
sudo rm -rf ./aws

# Helm
sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod 700 get_helm.sh
sudo ./get_helm.sh
sudo rm get_helm.sh

# yq (required for EKS-D artifacts)
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod a+x /usr/local/bin/yq

# jq (required for the EBS CSI script)
sudo apt-get install jq -y

# Python (required for the EBS CSI script)
sudo apt-get install python3-pip -y
sudo pip3 install boto3 
sudo pip3 install retrying 
sudo pip3 install requests 
sudo pip3 install pyudev
