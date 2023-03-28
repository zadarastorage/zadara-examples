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
  lb_url             = "https://${var.master_load_balancer_private_ip}:9345"

  rke_san = [
    var.master_load_balancer_public_ip,
    var.master_load_balancer_private_ip,
    local.master_lb_hostname,
    var.master_load_balancer_internal_dns
  ]

  iam_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:*",
                "ec2:*",
                "elasticloadbalancing:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "random_uuid" "random_cluster_id" {}

module "master_instance_profile" {
  count             = var.master_instance_profile == null ? 1 : 0
  source            = "./modules/instance-profile"
  iam_policy        = local.iam_policy
  iam_role_name     = var.master_iam_role == null ? "${var.environment}-masters-role" : var.master_iam_role
  use_existing_role = var.master_iam_role != null
  name              = "${var.environment}-masters-instance-profile"
}

locals {
  masters_instance_profile = var.master_instance_profile != null ? var.master_instance_profile : module.master_instance_profile[0].instance_profile_name
}

module "masters_asg" {
  source             = "./modules/asg"
  group_name         = "${var.environment}-master"
  image_id           = var.rke2_ami_id
  instance_type      = var.master_instance_type
  instance_profile   = local.masters_instance_profile
  key_pair_name      = var.master_key_pair
  rke_cni            = var.k8s_cni
  rke_masters_lb_url = local.lb_url
  rke_token          = random_uuid.random_cluster_id.result
  rke_san            = local.rke_san
  api_url            = var.zcompute_private_api != null ? var.zcompute_private_api : var.zcompute_api
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
      key   = "rke2.io/role"
      value = "master"
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
