data "cloudinit_config" "this" {
  gzip          = true
  base64_encode = true

  # Main cloud-init config file
  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content      = templatefile(var.template_file, {
      token         = var.rke_token
      cni           = var.rke_cni
      san           = var.rke_san
      taint_servers = var.taint_servers
      node_labels   = var.node_labels
      api_url       = var.api_url
      server_url    = var.rke_masters_lb_url
    })
  }

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/files/rke2-init.template.sh", {
      type          = var.is_agent ? "agent" : "server"
      token         = var.rke_token
      api_url       = var.api_url
      asg_name      = var.group_name
      server_url    = var.rke_masters_lb_url
    })
  }
}

resource "aws_launch_configuration" "rke" {
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
    ignore_changes        = [metadata_options]
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "rke" {
  name                 = var.group_name
  launch_configuration = aws_launch_configuration.rke.id
  termination_policies = ["OldestInstance", "NewestInstance", "OldestLaunchConfiguration", "Default"]
  max_size             = var.max_size
  min_size             = var.min_size
  desired_capacity     = var.desired_size
  vpc_zone_identifier  = var.subnet_ids

  target_group_arns = var.target_groups_arns

  dynamic "tag" {
    for_each = var.instance_tags
    content {
      key                 = tag.value["key"]
      value               = tag.value["value"]
      propagate_at_launch = true
    }
  }
}