resource "aws_lb_target_group" "kube_master" {
  name     = "${var.environment}-kube-masters"
  port     = var.k8s_api_server_port
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    protocol            = "TCP"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "kube_internal_master" {
  name     = "${var.environment}-kube-internal-masters"
  port     = 9345
  protocol = "TCP"
  vpc_id   = var.vpc_id

  stickiness {
    type = "source_ip"
  }

  health_check {
    protocol            = "TCP"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
    port                = 9345
  }

  lifecycle {
    ignore_changes = [stickiness]
  }
}

resource "aws_lb_listener" "kube_master" {
  default_action {
    target_group_arn = aws_lb_target_group.kube_master.arn
    type             = "forward"
  }

  load_balancer_arn = var.master_load_balancer_id
  port              = var.k8s_api_server_port
  protocol          = "TCP"
}

resource "aws_lb_listener" "kube_internal_master" {
  default_action {
    target_group_arn = aws_lb_target_group.kube_internal_master.arn
    type             = "forward"
  }

  load_balancer_arn = var.master_load_balancer_id
  port              = 9345
  protocol          = "TCP"
}

locals {
  master_lb_hostname = var.master_load_balancer_internal_dns != "" ? split(".", var.master_load_balancer_internal_dns)[0] : ""
  lb_url         = "https://${var.master_load_balancer_private_ip}:9345"

  rke_san = [
    var.master_load_balancer_public_ip,
    var.master_load_balancer_private_ip,
    local.master_lb_hostname,
    var.master_load_balancer_internal_dns
  ]
}

resource "random_uuid" "random_cluster_id" {}

module "servers_asg" {
  count              = var.masters_count
  source             = "./modules/asg"
  group_name         = "${var.cluster_name}-master"
  image_id           = var.rke2_ami_id
  instance_type      = var.master_instance_type
  instance_profile   = var.master_instance_profile
  key_pair_name      = var.master_key_pair
  rke_cni            = var.k8s_cni
  rke_masters_lb_url     = local.lb_url
  rke_token          = random_uuid.random_cluster_id.result
  rke_san            = local.rke_san
  api_url            = var.zcompute_api
  is_agent           = false
  taint_servers      = var.taint_masters
  security_groups    = var.security_groups_ids
  subnet_ids         = var.private_subnets_ids
  target_groups_arns = [aws_lb_target_group.kube_master.arn, aws_lb_target_group.kube_internal_master.arn]
  template_file      = "${path.module}/templates/rke-server-cloudinit.template.yaml"
  volume_size        = var.master_volume_size

  max_size     = var.masters_count
  min_size     = var.masters_count
  desired_size = var.masters_count

  instance_tags = [
    {
      key   = "Role"
      value = "server"
    },
    {
      key   = "Environment"
      value = var.environment
    },
    {
      key   = "kubernetes.io/cluster/${var.cluster_name}"
      value = "owned"
    }
  ]
}
