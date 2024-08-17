#!/bin/bash
set -x

export NEEDRESTART_MODE=a
export DEBIAN_FRONTEND=noninteractive

# Kubernetes binaries (and their prerequisites)
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${EKSD_K8S_VERSION/-/.}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${EKSD_K8S_VERSION/-/.}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# EKS-D manifest
sudo curl -L -o /tmp/manifest.yaml https://distro.eks.amazonaws.com/kubernetes-${EKSD_K8S_VERSION}/kubernetes-${EKSD_K8S_VERSION}-eks-${EKSD_REVISION}.yaml
KUBEADM=$(yq '.status.components.[].assets.[] | select(.name=="bin/linux/amd64/kubeadm") | .archive.uri' /tmp/manifest.yaml)
KUBELET=$(yq '.status.components.[].assets.[] | select(.name=="bin/linux/amd64/kubelet") | .archive.uri' /tmp/manifest.yaml)
KUBECTL=$(yq '.status.components.[].assets.[] | select(.name=="bin/linux/amd64/kubectl") | .archive.uri' /tmp/manifest.yaml)
KUBE_VER=$(yq '.status.components.[] | select(.name=="kubernetes") | .gitTag' /tmp/manifest.yaml)-eks-${EKSD_K8S_VERSION}-${EKSD_REVISION}
COREDNS=$(yq '.status.components.[].assets.[] | select(.name=="coredns-image") | .image.uri' /tmp/manifest.yaml)
ETCD=$(yq '.status.components.[].assets.[] | select(.name=="etcd-image") | .image.uri' /tmp/manifest.yaml)

# EKS-D binaries (overriding the original Kubernetes ones)
sudo rm /usr/bin/kubelet /usr/bin/kubeadm /usr/bin/kubectl
sudo wget -O /usr/bin/kubeadm $KUBEADM
sudo wget -O /usr/bin/kubelet $KUBELET
sudo wget -O /usr/bin/kubectl $KUBECTL
sudo chmod +x /usr/bin/kubelet /usr/bin/kubeadm /usr/bin/kubectl
sudo systemctl enable kubelet

# EKS-D images
# attempting to gather all artifacts will fail due to bad coredns & etcd naming convention (known issue) but relevant for other images
sudo kubeadm config images pull --image-repository public.ecr.aws/eks-distro/kubernetes --kubernetes-version $KUBE_VER || true
sudo ctr --namespace k8s.io images pull $COREDNS
sudo ctr --namespace k8s.io images pull $ETCD
