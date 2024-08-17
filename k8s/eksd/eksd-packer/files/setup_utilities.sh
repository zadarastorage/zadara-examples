#!/bin/bash
set -x

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

# ETCD (required for etcdctl snapshot save operation)
sudo mkdir -p /tmp/etcd-download
sudo curl -L https://github.com/etcd-io/etcd/releases/download/v3.5.11/etcd-v3.5.11-linux-amd64.tar.gz -o /tmp/etcd-linux-amd64.tar.gz
sudo tar xzvf /tmp/etcd-linux-amd64.tar.gz -C /tmp/etcd-download --strip-components=1
sudo rm -f /tmp/etcd-linux-amd64.tar.gz
sudo mv /tmp/etcd-download/etcdctl /usr/local/bin/etcdctl
sudo mv /tmp/etcd-download/etcdutl /usr/local/bin/etcdutl
sudo chmod a+x /usr/local/bin/etcdctl /usr/local/bin/etcdutl
sudo rm -rf /tmp/etcd-download
