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
wget https://get.helm.sh/helm-v3.11.2-linux-amd64.tar.gz
tar -zxvf helm-v3.11.2-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update

# yq (required for EKS-D artifacts)
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod a+x /usr/local/bin/yq
