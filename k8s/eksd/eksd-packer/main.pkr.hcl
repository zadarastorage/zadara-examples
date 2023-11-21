packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name                     = "eksd-ubuntu-{{timestamp}}_${var.eksd_k8s_version}-${var.eksd_revision}"
  instance_type                = var.instance_type
  region                       = "symphony"
  custom_endpoint_ec2          = "https://${var.api_endpoint}/api/v2/aws/ec2"
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
    volume_size = 30
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

  # Initialization & kernel upgrade 
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "NEEDRESTART_MODE=a"
    ]
    inline = [
      "sudo cloud-init status --wait",
      "echo set debconf to Noninteractive",
      "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections",
      "sudo apt-get update",
      "sudo apt-get dist-upgrade -y"
    ]
  }

  # Utilities (AWS CLI, Helm, yq)
  provisioner "file" {
    source      = "files/setup_utilities.sh"
    destination = "/tmp/setup_utilities.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo chmod +x /tmp/setup_utilities.sh",
      "sudo /tmp/setup_utilities.sh",
    ]
  }

  # Container runtime (containerd)
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

  # Add-ons artifacts (CNI, CSI, etc.)
  provisioner "file" {
    source      = "files/setup_addons.sh"
    destination = "/tmp/setup_addons.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo chmod +x /tmp/setup_addons.sh",
      "sudo /tmp/setup_addons.sh",
    ]
  }

  # EKS-D artifacts (Kubernetes, EKS-D, etc.)
  provisioner "file" {
    source      = "files/setup_eksd.sh"
    destination = "/tmp/setup_eksd.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo chmod +x /tmp/setup_eksd.sh",
      "sudo EKSD_K8S_VERSION=${var.eksd_k8s_version} EKSD_REVISION=${var.eksd_revision} /tmp/setup_eksd.sh",
    ]
  }

  # Support for the EBS CSI (new devices kernel trigger - add relpath based on the device name)
  provisioner "file" {
    source      = "files/zadara_disk_mapper.py"
    destination = "/tmp/zadara_disk_mapper.py"
  }

  provisioner "file" {
    source      = "files/zadara_disk_mapper.rules"
    destination = "/tmp/zadara_disk_mapper.rules"
  }

  provisioner "shell" {
    inline = [
      "sudo cp /tmp/zadara_disk_mapper.py /usr/bin/zadara_disk_mapper.py",
      "sudo cp /tmp/zadara_disk_mapper.rules /etc/udev/rules.d/zadara_disk_mapper.rules",
      "sudo chmod +x /usr/bin/zadara_disk_mapper.py",
      "sudo rm /tmp/zadara_disk_mapper.rules /tmp/zadara_disk_mapper.py",
      # Remove snap auto-import rule for block devices automated mounting
      "sudo rm /lib/udev/rules.d/66-snapd-autoimport.rules",
      # Remove the udev service networking limitation (required for the zadara_disk_mapper to be able and reach AWS API)
      "sudo sed -i '/IPAddressDeny=any/d' /lib/systemd/system/systemd-udevd.service",
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      # TODO - fix hostname in cloud-init config
      "sudo cloud-init clean",
      "rm -rf /home/ubuntu/.ssh/authorized_keys",
      "touch /home/ubuntu/.ssh/authorized_keys",
      "chmod 0600 /home/ubuntu/.ssh/authorized_keys",
    ]
  }
}