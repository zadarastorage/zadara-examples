packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name                     = "eksd-${var.eksd_k8s_version}-${var.eksd_revision}-ubuntu-{{timestamp}}"
  instance_type                = var.instance_type
  region                       = "symphony"
  custom_endpoint_ec2          = "https://${var.zcompute_api}/api/v2/aws/ec2"
  insecure_skip_tls_verify     = true
  communicator                 = "ssh"
  source_ami                   = var.ami_id
  ssh_username                 = var.ssh_username
  subnet_id                    = var.subnet_id
  ssh_interface                = "private_ip"
  ssh_private_key_file         = var.private_keypair_path
  ssh_bastion_host             = var.bastion_public_ip
  ssh_bastion_port             = 22
  ssh_bastion_username         = var.ssh_bastion_username
  ssh_bastion_private_key_file = var.private_keypair_path
  ssh_keypair_name             = var.ssh_keypair_name

  launch_block_device_mappings {
    device_name = "/dev/vda1"
    volume_size = 20
    #volume_type = "gp2"
    delete_on_termination = true
  }

  tag {
    key   = "eksd-manifest"
    value = "v${var.eksd_k8s_version}-eks-${var.eksd_revision}"
  }
  tag {
    key   = "last-build"
    value = formatdate("DD-MMM-YY", timestamp())
  }
}

build {
  name    = "eksd-ubuntu"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  # Utilities 
  provisioner "shell" {
    inline = [
      "sudo cloud-init status --wait",
      "echo set debconf to Noninteractive",
      "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections",
      "sudo apt-get update",
      "sudo apt-get install unzip -y",
      "sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64",
      "sudo chmod a+x /usr/local/bin/yq",
      "sudo curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
      "sudo unzip -o awscliv2.zip",
      "sudo ./aws/install --update",
      "sudo rm ./awscliv2.zip",
      "sudo rm -rf ./aws"
    ]
  }

  # Container runtime
  provisioner "file" {
    source      = "files/setup_containerd.sh"
    destination = "/tmp/setup_containerd.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo chmod +x /tmp/setup_containerd.sh",
      "sudo /tmp/setup_containerd.sh",
    ]
  }

  # Kubernetes artifacts
  provisioner "shell" {
    inline = [
      "echo set debconf to Noninteractive",
      "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections",
      "sudo apt-get update",
      "sudo apt-get install -y apt-transport-https ca-certificates curl",
      "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg",
      "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update",
      "sudo apt-get install -y kubelet kubeadm kubectl",
      "sudo apt-mark hold kubelet kubeadm kubectl",
    ]
  }

  # EKS-D artifacts
  provisioner "shell" {
    inline = [
      "sudo curl -L -o /tmp/manifest.yaml https://distro.eks.amazonaws.com/kubernetes-${var.eksd_k8s_version}/kubernetes-${var.eksd_k8s_version}-eks-${var.eksd_revision}.yaml",
      "export KUBEADM=$(yq '.status.components.[].assets.[] | select(.name==\"bin/linux/amd64/kubeadm\") | .archive.uri' /tmp/manifest.yaml)",
      "export KUBELET=$(yq '.status.components.[].assets.[] | select(.name==\"bin/linux/amd64/kubelet\") | .archive.uri' /tmp/manifest.yaml)",
      "export KUBECTL=$(yq '.status.components.[].assets.[] | select(.name==\"bin/linux/amd64/kubectl\") | .archive.uri' /tmp/manifest.yaml)",
      "export KUBE_VER=$(yq '.status.components.[] | select(.name==\"kubernetes\") | .gitTag' /tmp/manifest.yaml)-eks-${var.eksd_k8s_version}-${var.eksd_revision}",
      "export COREDNS=$(yq '.status.components.[].assets.[] | select(.name==\"coredns-image\") | .image.uri' /tmp/manifest.yaml)",
      "export ETCD=$(yq '.status.components.[].assets.[] | select(.name==\"etcd-image\") | .image.uri' /tmp/manifest.yaml)",
      "sudo rm /usr/bin/kubelet /usr/bin/kubeadm /usr/bin/kubectl",
      "sudo wget -O /usr/bin/kubeadm $KUBEADM",
      "sudo wget -O /usr/bin/kubelet $KUBELET",
      "sudo wget -O /usr/bin/kubectl $KUBECTL",
      "sudo chmod +x /usr/bin/kubelet /usr/bin/kubeadm /usr/bin/kubectl",
      "sudo systemctl enable kubelet",
      # attempt to gather all artifacts will fail due to bad coredns & etcd naming convention (known issue) but relevant for other images
      "sudo kubeadm config images pull --image-repository public.ecr.aws/eks-distro/kubernetes --kubernetes-version $KUBE_VER || true",
      "sudo ctr --namespace k8s.io images pull $COREDNS",
      "sudo ctr --namespace k8s.io images tag $COREDNS $${COREDNS%'-eks-${var.eksd_k8s_version}-${var.eksd_revision}'}",
      "sudo ctr --namespace k8s.io images pull $ETCD",
      "sudo ctr --namespace k8s.io images tag $ETCD $${ETCD%'-eks-${var.eksd_k8s_version}-${var.eksd_revision}'}-0",
    ]
  }

  provisioner "file" {
    source      = "files/start_eksd_node.sh"
    destination = "/tmp/start_eksd_node.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo cp /tmp/start_eksd_node.sh /usr/bin/start_eksd_node.sh",
      "sudo chmod +x /usr/bin/start_eksd_node.sh",
      "sudo rm /tmp/start_eksd_node.sh",
      # TODO - fix hostname in cloud-init config
      "sudo cloud-init clean",
      "rm -rf /home/ubuntu/.ssh/authorized_keys",
      "touch /home/ubuntu/.ssh/authorized_keys",
      "chmod 0600 /home/ubuntu/.ssh/authorized_keys",
    ]
  }
}