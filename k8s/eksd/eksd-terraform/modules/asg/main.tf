data "cloudinit_config" "this" {
  gzip          = true
  base64_encode = true

  # Control-plain files for OOTB deployments/operations
  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/files/cloudinit-server.template.yaml", {
      token        = var.eksd_token
      server_url   = var.eksd_masters_lb_url
      cluster_name = var.cluster_name
      pod_network  = var.pod_network
      certificate  = var.eksd_certificate
      san          = var.eksd_san
      root_ca_cert = var.root_ca_cert
    })
  }

  # Unified initialization script for servers & workers
  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/files/eksd-init.template.sh", {
      type                  = var.is_worker ? "worker" : "server"
      token                 = var.eksd_token
      asg_name              = var.group_name
      server_url            = var.eksd_masters_lb_url
      certificate           = var.eksd_certificate
      cluster_name          = var.cluster_name
      cni_provider          = var.cni_provider
      pod_network           = var.pod_network
      install_ebs_csi       = var.install_ebs_csi
      ebs_csi_volume_type   = var.ebs_csi_volume_type
      install_lb_controller = var.install_lb_controller
      vpc_id                = var.vpc_id
      install_autoscaler    = var.install_autoscaler
      install_kasten_k10    = var.install_kasten_k10
      root_ca_cert          = var.root_ca_cert
    })
  }

}

resource "aws_launch_configuration" "eksd" {
  image_id             = var.image_id
  instance_type        = var.instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = var.instance_profile
  security_groups      = var.security_groups
  user_data_base64     = data.cloudinit_config.this.rendered

  root_block_device {
    delete_on_termination = "true"
    encrypted             = "false"
    volume_size           = var.volume_size
    volume_type           = var.volume_type
  }

  lifecycle {
    ignore_changes        = [metadata_options, root_block_device]
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "eksd" {
  name                 = var.group_name
  launch_configuration = aws_launch_configuration.eksd.id
  termination_policies = ["OldestInstance", "NewestInstance", "OldestLaunchConfiguration", "Default"]
  max_size             = var.max_size
  min_size             = var.min_size
  desired_capacity     = var.desired_size
  vpc_zone_identifier  = var.subnet_ids
  target_group_arns    = var.target_group_arns

  dynamic "tag" {
    for_each = var.instance_tags
    content {
      key                 = tag.value["key"]
      value               = tag.value["value"]
      propagate_at_launch = true
    }
  }
}
