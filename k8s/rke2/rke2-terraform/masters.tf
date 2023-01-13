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

  iam_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:UpdateAutoScalingGroup",
                "ec2:AttachVolume",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CreateRoute",
                "ec2:CreateSecurityGroup",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteRoute",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteVolume",
                "ec2:DescribeInstances",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVolumes",
                "ec2:DescribeVolumesModifications",
                "ec2:DescribeVpcs",
                "ec2:DescribeDhcpOptions",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DetachVolume",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifyVolume",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeInternetGateways",
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
                "elasticloadbalancing:AttachLoadBalancerToSubnets",
                "elasticloadbalancing:ConfigureHealthCheck",
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateLoadBalancerListeners",
                "elasticloadbalancing:CreateLoadBalancerPolicy",
                "elasticloadbalancing:CreateTargetGroup",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:DeleteLoadBalancerListeners",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                "elasticloadbalancing:DeregisterTargets",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeLoadBalancerPolicies",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DetachLoadBalancerFromSubnets",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
                "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
                "kms:DescribeKey"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "iam:CreateServiceLinkedRole",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                }
            }
        }
    ]
}
EOF
}

resource "random_uuid" "random_cluster_id" {}

module "masters_instance_profile" {
  source = "./modules/instance-profile"
  iam_policy = local.iam_policy
  iam_role_name = "${var.environment}-masters-role"
  name = "${var.environment}-masters-instance-profile"
}

module "masters_asg" {
  count              = var.masters_count
  source             = "./modules/asg"
  group_name         = "${var.cluster_name}-master"
  image_id           = var.rke2_ami_id
  instance_type      = var.master_instance_type
  instance_profile   = module.masters_instance_profile.instance_profile_name
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
