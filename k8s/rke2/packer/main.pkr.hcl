packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
    qemu = {
      version = ">= 1.0.2"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "amazon-ebs" "centos" {
  ami_name                     = "rke2-centos-{{timestamp}}"
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

  tag {
    key   = "rke2-k8s-version"
    value = var.rke2_k8s_version
  }
  tag {
    key   = "rke2-revision"
    value = var.rke2_revision
  }
  tag {
    key   = "last-build"
    value = formatdate("DD-MMM-YY", timestamp())
  }
}


source "qemu" "centos" {

  iso_url              = "https://cloud.centos.org/centos/7/images/CentOS-7-aarch64-GenericCloud-2003.qcow2"
  iso_checksum         = "md5:51f8a9800bf19cfbfe1525c000973b4e"
  disk_image           = true
  output_directory     = "output_centos_rke"
  shutdown_command     = "echo 'packer' | sudo -S shutdown -P now"
  disk_size            = "10000M"
  format               = "qcow2"
  disk_compression     = true
  #  accelerator       = "kvm"
  http_directory       = "."
  ssh_port             = 22
  ssh_private_key_file = var.private_keypair_path
  ssh_username         = "centos"
  ssh_timeout          = "20m"
  vm_name              = "centos-7.8-rke2-${var.rke2_k8s_version}-${var.rke2_revision}.qcow2"
  net_device           = "virtio-net"
  disk_interface       = "virtio"
  boot_wait            = "10s"
  cd_content           = {
    "meta-data" = file("./files/meta-data")
    "user-data" = templatefile("./files/user-data.pkrtpl.hcl", {
      public_key_content = file("${var.private_keypair_path}.pub")
    })
  }
  cd_label            = "cidata"
  use_default_display = true
}

build {
  name    = "rke2-centos"
  sources = [
    "source.amazon-ebs.centos",
    "source.qemu.centos"
  ]

  ## cgroup centos 7 memory fix
  provisioner "file" {
    source      = "files/cgroup-memory-fix.sh"
    destination = "/tmp/cgroup-memory-fix.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /var/lib/rancher/rke2/agent/images/",
      "sudo curl -L -o /var/lib/rancher/rke2/agent/images/rke2-images-calico.linux-amd64.tar.zst https://github.com/rancher/rke2/releases/download/${var.rke2_k8s_version}%2B${var.rke2_revision}/rke2-images-calico.linux-amd64.tar.zst",
      "sudo curl -L -o /var/lib/rancher/rke2/agent/images/rke2-images-core.linux-amd64.tar.zst https://github.com/rancher/rke2/releases/download/${var.rke2_k8s_version}%2B${var.rke2_revision}/rke2-images-core.linux-amd64.tar.zst",
      "sudo chmod +x /tmp/cgroup-memory-fix.sh",
      "sudo /tmp/cgroup-memory-fix.sh",
      "sudo grub2-mkconfig -o /etc/default/grub",
    ]
  }

  # RKE2 configuration and installation
  provisioner "file" {
    source      = "files/rke2containerd.sh"
    destination = "/tmp/rke2containerd.sh"
  }

  provisioner "file" {
    source      = "files/rke.conf"
    destination = "/tmp/rke.conf"
  }

  provisioner "shell" {
    inline = [
      "sudo cp /tmp/rke2containerd.sh /etc/profile.d/rke2containerd.sh",
      "sudo mkdir -p /etc/NetworkManager/conf.d/",
      "sudo cp /tmp/rke.conf /etc/NetworkManager/conf.d/rke.conf",
    ]
  }

  provisioner "file" {
    source      = "files/setup_rke2_node.sh"
    destination = "/tmp/setup_rke2_node.sh"
  }

  # Download rke2 installation script
  provisioner "shell" {
    inline = [
      "sudo chmod +x /tmp/setup_rke2_node.sh",
      "sudo INSTALL_RKE2_VERSION=${var.rke2_k8s_version}+${var.rke2_revision} /tmp/setup_rke2_node.sh",
    ]
  }

  provisioner "file" {
    source      = "files/start_rke2_node.sh"
    destination = "/tmp/start_rke2_node.sh"
  }

  provisioner "file" {
    source      = "files/wait_for_rke2_node.sh"
    destination = "/tmp/wait_for_rke2_node.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo cp /tmp/start_rke2_node.sh /usr/bin/start_rke2_node.sh",
      "sudo chmod +x /usr/bin/start_rke2_node.sh",
      "sudo cp /tmp/wait_for_rke2_node.sh /usr/bin/wait_for_rke2_node.sh",
      "sudo chmod +x /usr/bin/wait_for_rke2_node.sh",
      "sudo rm /tmp/setup_rke2_node.sh /tmp/start_rke2_node.sh /usr/bin/wait_for_rke2_node.sh",
      "sudo cloud-init clean",
      "rm -rf /home/centos/.ssh/authorized_keys",
      "touch /home/centos/.ssh/authorized_keys",
      "chmod 0600 /home/centos/.ssh/authorized_keys",
      "sudo yum install epel-release -y",
      "sudo yum install jq -y",
      "sudo yum install unzip -y",
      "sudo curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
      "sudo unzip -o awscliv2.zip",
      "sudo ./aws/install --update"
    ]
  }
}