data "cloudinit_config" "this" {
  gzip          = true
  base64_encode = true

  # Control-plain files for OOTB deployments/operations
  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/files/cloudinit-server.template.yaml", {
      token                    = var.eksd_token
      server_url               = var.eksd_masters_lb_url
      cluster_name             = var.cluster_name
      pod_network              = var.pod_network
      certificate              = var.eksd_certificate
      san                      = var.eksd_san
      root_ca_cert             = var.root_ca_cert
      backup_access_key_id     = var.backup_access_key_id
      backup_secret_access_key = var.backup_secret_access_key
      backup_region            = var.backup_region
      backup_endpoint          = var.backup_endpoint
      backup_bucket            = var.backup_bucket
      backup_rotation          = var.backup_rotation
    })
  }

  # Unified initialization script for servers & workers
  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/files/eksd-init.template.sh", {
      type                       = var.is_worker ? "worker" : "server"
      token                      = var.eksd_token
      group_name                 = var.group_name
      server_url                 = var.eksd_masters_lb_url
      certificate                = var.eksd_certificate
      cluster_name               = var.cluster_name
      cni_provider               = var.cni_provider
      pod_network                = var.pod_network
      install_ebs_csi            = var.install_ebs_csi
      ebs_csi_volume_type        = var.ebs_csi_volume_type
      install_lb_controller      = var.install_lb_controller
      vpc_id                     = var.vpc_id
      install_autoscaler         = var.install_autoscaler
      install_kasten_k10         = var.install_kasten_k10
      root_ca_cert               = var.root_ca_cert
      manage_instances_using_asg = var.manage_instances_using_asg
    })
  }

}

resource "aws_launch_configuration" "eksd" {
  name                 = "${var.group_name}-launch-config-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  image_id             = var.image_id
  instance_type        = var.instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = var.instance_profile.unique_id
  security_groups      = var.security_groups
  user_data_base64     = data.cloudinit_config.this.rendered

  root_block_device {
    delete_on_termination = "true"
    encrypted             = "false"
    volume_size           = var.volume_size
    volume_type           = var.volume_type
  }

  lifecycle {
    ignore_changes        = [metadata_options, root_block_device, name]
    create_before_destroy = true
  }
}

locals {
  instance_tags = {for k, v in var.instance_tags: v["key"] => v["value"]}
}

data "aws_autoscaling_group" "eksd_asg" {
  count =  var.keep_existing_asg_state ? 1 : 0
  name = var.group_name
}

locals {
  existing_asg_min_size = try(data.aws_autoscaling_group.eksd_asg[0].min_size, 0)
  existing_asg_max_size = try(data.aws_autoscaling_group.eksd_asg[0].max_size, 0)
  existing_asg_desired_capacity = try(data.aws_autoscaling_group.eksd_asg[0].desired_capacity, 0)
  starting_standalone_instance_index = 1
}

resource "aws_autoscaling_group" "eksd" {
  name                      = var.group_name
  default_cooldown          = var.asg_cooldown
  launch_configuration      = aws_launch_configuration.eksd.id
  termination_policies      = ["OldestInstance", "NewestInstance", "OldestLaunchConfiguration", "Default"]
  min_size                  = var.manage_instances_using_asg ? var.min_size : local.existing_asg_min_size
  max_size                  = var.manage_instances_using_asg ? var.max_size : local.existing_asg_max_size
  desired_capacity          = var.manage_instances_using_asg ? var.desired_size : local.existing_asg_desired_capacity
  wait_for_capacity_timeout = var.asg_timeout
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = var.target_group_arns

  dynamic "tag" {
    for_each = var.instance_tags
    content {
      key                 = tag.value["key"]
      value               = tag.value["value"]
      propagate_at_launch = true
    }
  }
}

resource "aws_instance" "group-instances" {
  count                     = var.manage_instances_using_asg ? 0 : var.desired_size
  ami                       = var.image_id
  instance_type             = var.instance_type
  key_name                  = var.key_pair_name
  subnet_id                 = var.subnet_ids[0]
  iam_instance_profile      = var.instance_profile.name
  vpc_security_group_ids    = var.security_groups
  user_data_base64          = data.cloudinit_config.this.rendered

  root_block_device {
    delete_on_termination = "true"
    encrypted             = "false"
    volume_size           = var.volume_size
    volume_type           = var.volume_type
  }

  tags = merge(local.instance_tags, {"Name"="${var.group_name}-sa-${format("%d", count.index + local.starting_standalone_instance_index)}"})

  lifecycle {
    ignore_changes        = [root_block_device, ami, tags["Name"], user_data_base64]
    create_before_destroy = true
  }
}
