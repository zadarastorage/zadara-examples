#!/bin/bash

export NEEDRESTART_MODE=a
export DEBIAN_FRONTEND=noninteractive

# Prerequisites
sudo mkdir -p /etc/kubernetes/zadara
sudo helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
sudo helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
sudo helm repo add eks https://aws.github.io/eks-charts
sudo helm repo add autoscaler https://kubernetes.github.io/autoscaler
sudo helm repo add kasten https://charts.kasten.io
sudo helm repo update

# General cloud-config
cat <<EOF | sudo tee /etc/kubernetes/zadara/cloud-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloud-config
data:
  cloud.conf: |
    [Global]
    Zone=us-east-1a
    [ServiceOverride "ec2"]
    Service=ec2
    Region=us-east-1
    URL=API_ENDPOINT/api/v2/aws/ec2
    SigningRegion=us-east-1
    [ServiceOverride "autoscaling"]
    Service=autoscaling
    Region=us-east-1
    URL=API_ENDPOINT/api/v2/aws/autoscaling
    SigningRegion=us-east-1
    [ServiceOverride "elasticloadbalancing"]
    Service=elasticloadbalancing
    Region=us-east-1
    URL=API_ENDPOINT/api/v2/aws/elbv2
    SigningRegion=us-east-1
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-meta
data:
  endpoint: API_ENDPOINT/api/v2/aws/ec2
EOF

# CCM (AWS Cloud Provider for Kubernetes)
sudo helm pull aws-cloud-controller-manager/aws-cloud-controller-manager -d /etc/kubernetes/zadara/
sudo helm template aws-cloud-controller-manager/aws-cloud-controller-manager | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %

# CNI (Flannel, Calico & Cilium)
sudo wget -qO /etc/kubernetes/zadara/kube-flannel.yml https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
sudo cat /etc/kubernetes/zadara/kube-flannel.yml | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %
CALICO_VERSION=$(curl -s -L https://api.github.com/repos/projectcalico/calico/releases/latest | jq -r '.tag_name')
sudo wget -qO /etc/kubernetes/zadara/tigera-operator.yaml https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
sudo cat /etc/kubernetes/zadara/tigera-operator.yaml | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %
sudo wget -qO /etc/kubernetes/zadara/custom-resources.yaml https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml
CILIUM_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
sudo curl -s -L -o /etc/kubernetes/zadara/cilium-linux-amd64.tar.gz https://github.com/cilium/cilium-cli/releases/download/${CILIUM_VERSION}/cilium-linux-amd64.tar.gz{,.sha256sum}

# CSI (External Snapshotter & AWS EBS CSI driver)
sudo wget -qO /etc/kubernetes/zadara/snapshot.storage.k8s.io_volumesnapshotclasses.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
sudo wget -qO /etc/kubernetes/zadara/snapshot.storage.k8s.io_volumesnapshotcontents.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
sudo wget -qO /etc/kubernetes/zadara/snapshot.storage.k8s.io_volumesnapshots.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
sudo wget -qO /etc/kubernetes/zadara/groupsnapshot.storage.k8s.io_volumegroupsnapshotclasses.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/groupsnapshot.storage.k8s.io_volumegroupsnapshotclasses.yaml
sudo wget -qO /etc/kubernetes/zadara/groupsnapshot.storage.k8s.io_volumegroupsnapshotcontents.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/groupsnapshot.storage.k8s.io_volumegroupsnapshotcontents.yaml
sudo wget -qO /etc/kubernetes/zadara/groupsnapshot.storage.k8s.io_volumegroupsnapshots.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/groupsnapshot.storage.k8s.io_volumegroupsnapshots.yaml
sudo wget -qO /etc/kubernetes/zadara/rbac-snapshot-controller.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
sudo wget -qO /etc/kubernetes/zadara/setup-snapshot-controller.yaml https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
sudo cat /etc/kubernetes/zadara/setup-snapshot-controller.yaml | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %
sudo helm pull aws-ebs-csi-driver/aws-ebs-csi-driver -d /etc/kubernetes/zadara/
sudo helm template aws-ebs-csi-driver/aws-ebs-csi-driver | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %
cat <<EOF | sudo tee /etc/kubernetes/zadara/values-aws-ebs-csi-driver.yaml
controller:
  region: 'us-east-1'
  volumes:
    - name: trusted-root-cas
      hostPath:
        path: /etc/ssl/certs/ca-certificates.crt
        type: File
  volumeMounts:
    - name: trusted-root-cas
      mountPath: /etc/ssl/certs/zadara-ca.crt
      readonly: true
sidecars:
  provisioner:
    additionalArgs:
      - --timeout=60s
      - --retry-interval-start=4s
  attacher:
    additionalArgs: 
      - --timeout=60s
      - --retry-interval-start=4s
storageClasses:
  - name: ebs-sc
    annotations:
      storageclass.kubernetes.io/is-default-class: "true"
    parameters:
      type: "gp2"
volumeSnapshotClasses: 
  - name: ebs-vsc
    annotations:
      snapshot.storage.kubernetes.io/is-default-class: "true"
      k10.kasten.io/is-snapshot-class: "true"
    deletionPolicy: Delete
EOF

# AWS Load Balancer Controller
sudo helm pull eks/aws-load-balancer-controller -d /etc/kubernetes/zadara/
sudo helm template eks/aws-load-balancer-controller --set clusterName=k8s | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %
cat <<EOF | sudo tee /etc/kubernetes/zadara/values-aws-load-balancer-controller.yaml
clusterName: CLUSTER_NAME
vpcId: VPC_ID
awsApiEndpoints: "ec2=API_ENDPOINT/api/v2/aws/ec2,elasticloadbalancing=API_ENDPOINT/api/v2/aws/elbv2,acm=API_ENDPOINT/api/v2/aws/acm,sts=API_ENDPOINT/api/v2/aws/sts"
enableShield: false
enableWaf: false
enableWafv2: false
region: us-east-1
ingressClassConfig:
  default: true
extraVolumes:
  - name: trusted-root-cas
    hostPath:
      path: /etc/ssl/certs/ca-certificates.crt
extraVolumeMounts:
  - name: trusted-root-cas
    mountPath: /etc/ssl/certs/zadara-ca.crt
    readonly: true
EOF

# Cluster Autoscaler
sudo helm pull autoscaler/cluster-autoscaler -d /etc/kubernetes/zadara/
sudo helm template autoscaler/cluster-autoscaler --set autoDiscovery.clusterName=k8s | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %
cat <<EOF | sudo tee /etc/kubernetes/zadara/values-cluster-autoscaler.yaml
awsRegion: us-east-1
autoDiscovery:
  clusterName: CLUSTER_NAME
cloudConfigPath: config/cloud.conf
extraVolumes:
  - name: cloud-config
    configMap:
      name: cloud-config
  - name: trusted-root-cas
    hostPath:
      path: /etc/ssl/certs/ca-certificates.crt
extraVolumeMounts:
  - name: cloud-config
    mountPath: config
  - name: trusted-root-cas
    mountPath: /etc/ssl/certs/zadara-ca.crt
    readonly: true
tolerations:
- effect: NoSchedule
  key: node-role.kubernetes.io/control-plane
  operator: Equal
nodeSelector:
  node-role.kubernetes.io/control-plane: ""
EOF

# Kasten
sudo helm pull kasten/k10 -d /etc/kubernetes/zadara/
sudo helm template kasten/k10 | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %
