#!/bin/bash
set -x
set > /tmp/setup_addons.env

# Versions to use
if [[ "${USE_LATEST_ADDONS}" == "true" ]]
then
  if [[ ! -z ${AWS_CLOUD_CONTROLLER_MANAGER_CHART_VERSION} ]]
  then
    AWS_CLOUD_CONTROLLER_MANAGER_CHART_VERSION="--version ${AWS_CLOUD_CONTROLLER_MANAGER_CHART_VERSION}"
  fi
  if [[ ! -z ${AWS_EBS_CSI_DRIVER_CHART_VERSION} ]]
  then
    AWS_EBS_CSI_DRIVER_CHART_VERSION="--version ${AWS_EBS_CSI_DRIVER_CHART_VERSION}"
  fi
  if [[ ! -z ${AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION} ]]
  then
    AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION="--version ${AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION}"
  fi
  if [[ ! -z ${CLUSTER_AUTO_SCALER_CHART_VERSION} ]]
  then
    CLUSTER_AUTO_SCALER_CHART_VERSION="--version ${CLUSTER_AUTO_SCALER_CHART_VERSION}"
  fi
  if [[ ! -z ${KASTEN_K10_CHART_VERSION} ]]
  then
    KASTEN_K10_CHART_VERSION="--version ${KASTEN_K10_CHART_VERSION}"
  fi
elif [[ "${EKSD_K8S_VERSION}" == "1-28" ]]
then
AWS_CLOUD_CONTROLLER_MANAGER_CHART_VERSION=${AWS_CLOUD_CONTROLLER_MANAGER_CHART_VERSION:-"--version 0.0.8"}
AWS_EBS_CSI_DRIVER_CHART_VERSION=${AWS_EBS_CSI_DRIVER_CHART_VERSION:-"--version 2.33.0"}
AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION=${AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION:-"--version 1.7.2"}
CLUSTER_AUTO_SCALER_CHART_VERSION=${CLUSTER_AUTO_SCALER_CHART_VERSION:-"--version 9.37.0"}
KASTEN_K10_CHART_VERSION=${KASTEN_K10_CHART_VERSION:-"--version 7.0.6"}
elif [[ "${EKSD_K8S_VERSION}" == "1-29" ]]
then
AWS_CLOUD_CONTROLLER_MANAGER_CHART_VERSION=${AWS_CLOUD_CONTROLLER_MANAGER_CHART_VERSION:-"--version 0.0.8"}
AWS_EBS_CSI_DRIVER_CHART_VERSION=${AWS_EBS_CSI_DRIVER_CHART_VERSION:-"--version 2.33.0"}
AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION=${AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION:-"--version 1.7.2"}
CLUSTER_AUTO_SCALER_CHART_VERSION=${CLUSTER_AUTO_SCALER_CHART_VERSION:-"--version 9.37.0"}
KASTEN_K10_CHART_VERSION=${KASTEN_K10_CHART_VERSION:-"--version 7.0.6"}
elif [[ "${EKSD_K8S_VERSION}" == "1-30" ]]
then
AWS_CLOUD_CONTROLLER_MANAGER_CHART_VERSION=${AWS_CLOUD_CONTROLLER_MANAGER_CHART_VERSION:-"--version 0.0.8"}
AWS_EBS_CSI_DRIVER_CHART_VERSION=${AWS_EBS_CSI_DRIVER_CHART_VERSION:-"--version 2.33.0"}
AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION=${AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION:-"--version 1.7.2"}
CLUSTER_AUTO_SCALER_CHART_VERSION=${CLUSTER_AUTO_SCALER_CHART_VERSION:-"--version 9.37.0"}
KASTEN_K10_CHART_VERSION=${KASTEN_K10_CHART_VERSION:-"--version 7.0.6"}
fi

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
sudo helm pull aws-cloud-controller-manager/aws-cloud-controller-manager ${AWS_CLOUD_CONTROLLER_MANAGER_CHART_VERSION} -d /etc/kubernetes/zadara/
sudo helm template aws-cloud-controller-manager/aws-cloud-controller-manager ${AWS_CLOUD_CONTROLLER_MANAGER_CHART_VERSION} \
          | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %

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
sudo helm pull aws-ebs-csi-driver/aws-ebs-csi-driver ${AWS_EBS_CSI_DRIVER_CHART_VERSION} -d /etc/kubernetes/zadara/
sudo helm template aws-ebs-csi-driver/aws-ebs-csi-driver ${AWS_EBS_CSI_DRIVER_CHART_VERSION} | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %
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
      readOnly: true
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
    allowVolumeExpansion: true
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
sudo helm pull eks/aws-load-balancer-controller ${AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION} -d /etc/kubernetes/zadara/
sudo helm template eks/aws-load-balancer-controller ${AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION} --set clusterName=k8s | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %
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
      type: File
extraVolumeMounts:
  - name: trusted-root-cas
    mountPath: /etc/ssl/certs/zadara-ca.crt
    readOnly: true
EOF

# Cluster Autoscaler
sudo helm pull autoscaler/cluster-autoscaler ${CLUSTER_AUTO_SCALER_CHART_VERSION} -d /etc/kubernetes/zadara/
sudo helm template autoscaler/cluster-autoscaler ${CLUSTER_AUTO_SCALER_CHART_VERSION} --set autoDiscovery.clusterName=k8s | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %
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
      type: File
extraVolumeMounts:
  - name: cloud-config
    mountPath: config
  - name: trusted-root-cas
    mountPath: /etc/ssl/certs/zadara-ca.crt
    readOnly: true
tolerations:
- effect: NoSchedule
  key: node-role.kubernetes.io/control-plane
  operator: Equal
nodeSelector:
  node-role.kubernetes.io/control-plane: ""
EOF

# Kasten
sudo helm pull kasten/k10 ${KASTEN_K10_CHART_VERSION} -d /etc/kubernetes/zadara/
sudo helm template kasten/k10 ${KASTEN_K10_CHART_VERSION} | grep image: | sed 's/image://' | sed 's/"//g' | sudo xargs -I % ctr --namespace k8s.io images pull %
