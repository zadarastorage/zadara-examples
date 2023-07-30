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
sudo helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
sudo helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
sudo helm repo update
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

# OOTB Kubernetes deployments (pre-download charts/files)
sudo mkdir -p /etc/kubernetes/zadara
sudo helm pull aws-cloud-controller-manager/aws-cloud-controller-manager -d /etc/kubernetes/zadara/
sudo helm pull aws-ebs-csi-driver/aws-ebs-csi-driver -d /etc/kubernetes/zadara/
sudo wget -qO /etc/kubernetes/zadara/kube-flannel.yml https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
sudo wget -qO /etc/kubernetes/zadara/tigera-operator.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
sudo wget -qO /etc/kubernetes/zadara/custom-resources.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml 
sudo wget -qO /etc/kubernetes/zadara/ebs-csi-storageclass.yaml https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/examples/kubernetes/snapshot/manifests/classes/storageclass.yaml
sudo wget -qO /etc/kubernetes/zadara/ebs-csi-snapshotclass.yaml https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/examples/kubernetes/snapshot/manifests/classes/snapshotclass.yaml
sudo wget -qO /etc/kubernetes/zadara/snapshot.storage.k8s.io_volumesnapshotclasses.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
sudo wget -qO /etc/kubernetes/zadara/snapshot.storage.k8s.io_volumesnapshotcontents.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
sudo wget -qO /etc/kubernetes/zadara/snapshot.storage.k8s.io_volumesnapshots.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
sudo wget -qO /etc/kubernetes/zadara/groupsnapshot.storage.k8s.io_volumegroupsnapshotclasses.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/groupsnapshot.storage.k8s.io_volumegroupsnapshotclasses.yaml
sudo wget -qO /etc/kubernetes/zadara/groupsnapshot.storage.k8s.io_volumegroupsnapshotcontents.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/groupsnapshot.storage.k8s.io_volumegroupsnapshotcontents.yaml
sudo wget -qO /etc/kubernetes/zadara/groupsnapshot.storage.k8s.io_volumegroupsnapshots.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/groupsnapshot.storage.k8s.io_volumegroupsnapshots.yaml
sudo wget -qO /etc/kubernetes/zadara/rbac-snapshot-controller.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
sudo wget -qO /etc/kubernetes/zadara/setup-snapshot-controller.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml

# Genera cloud-config file (for the AWS CCM and others...)
cat <<EOF | sudo tee /etc/kubernetes/zadara/cloud-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloud-config
data:
  cloud.conf: |
    [Global]
    Zone=eu-west-1a
    [ServiceOverride "ec2"]
    Service=ec2
    Region=eu-west-1
    URL=API_ENDPOINT/api/v2/aws/ec2
    SigningRegion=eu-west-1
    [ServiceOverride "autoscaling"]
    Service=autoscaling
    Region=eu-west-1
    URL=API_ENDPOINT/api/v2/aws/autoscaling
    SigningRegion=eu-west-1
    [ServiceOverride "elasticloadbalancing"]
    Service=elasticloadbalancing
    Region=eu-west-1
    URL=API_ENDPOINT/api/v2/aws/elbv2
    SigningRegion=eu-west-1
EOF

# Generate value file for the EBS CSI
cat <<EOF | sudo tee /etc/kubernetes/zadara/values-aws-ebs-csi-driver.yaml
controller:
  env:
    - name: AWS_EC2_ENDPOINT
      value: 'API_ENDPOINT/api/v2/aws/ec2'
    - name: AWS_REGION
      value: 'symphony'
EOF
