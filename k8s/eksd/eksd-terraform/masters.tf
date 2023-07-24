resource "aws_lb_target_group" "kube_master" {
  name     = "eksd-${var.environment}-masters"
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

resource "aws_lb_listener" "kube_master" {
  default_action {
    target_group_arn = aws_lb_target_group.kube_master.arn
    type             = "forward"
  }

  load_balancer_arn = var.masters_load_balancer_id
  port              = var.k8s_api_server_port
  protocol          = "TCP"
}

locals {
  master_lb_hostname = var.masters_load_balancer_internal_dns != "" ? split(".", var.masters_load_balancer_internal_dns)[0] : ""
  lb_url             = "${var.masters_load_balancer_private_ip}:6443"

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

resource "random_string" "random_cluster_token_id" {
  length  = 6
  special = false
  upper   = false
}

resource "random_password" "random_cluster_token_secret" {
  length  = 16
  special = false
  upper   = false
}

resource "random_password" "random_cluster_certificate" {
  length  = 32
  special = false
  lower   = false
  upper   = false
}

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
  source              = "./modules/asg"
  cluster_name        = var.environment
  group_name          = "${var.environment}-master"
  image_id            = var.eksd_ami_id
  instance_type       = var.master_instance_type
  instance_profile    = local.masters_instance_profile
  key_pair_name       = var.masters_key_pair
  eksd_masters_lb_url = local.lb_url
  eksd_token          = "${random_string.random_cluster_token_id.result}.${random_password.random_cluster_token_secret.result}"
  eksd_certificate    = random_password.random_cluster_certificate.result
  api_url             = var.zcompute_private_api != null ? var.zcompute_private_api : var.zcompute_api
  is_worker           = false
  security_groups     = [var.security_group_id]
  subnet_ids          = [var.private_subnet_id]
  target_group_arn    = aws_lb_target_group.kube_master.arn
  volume_size         = var.masters_volume_size
  pod_network         = var.pod_network
  controller_image_version = var.controller_image_version

  max_size     = var.masters_count
  min_size     = var.masters_count
  desired_size = var.masters_count

  instance_tags = [
    {
      key   = "kubernetes.io/role"
      value = "master"
    },
    {
      key   = "Environment"
      value = var.environment
    },
    {
      key   = "kubernetes.io/cluster/${var.environment}"
      value = "owned"
    }
  ]
}
