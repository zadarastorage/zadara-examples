module "worker_instance_profile" {
  count             = var.worker_instance_profile == null ? 1 : 0
  source            = "./modules/instance-profile"
  iam_policy        = local.iam_policy
  iam_role_name     = var.worker_iam_role == null ? "${var.environment}-workers-role" : var.worker_iam_role
  use_existing_role = var.worker_iam_role != null
  name              = "${var.environment}-workers-instance-profile"
}

locals {
  workers_instance_profile = var.worker_instance_profile != null ? var.worker_instance_profile : module.worker_instance_profile[0].instance_profile_name
}

module "workers_asg" {
  source             = "./modules/asg"
  group_name         = "${var.environment}-worker"
  image_id           = var.rke2_ami_id
  instance_type      = var.worker_instance_type
  instance_profile   = local.workers_instance_profile
  key_pair_name      = var.worker_key_pair
  rke_cni            = var.k8s_cni
  rke_masters_lb_url = local.lb_url
  rke_token          = random_uuid.random_cluster_id.result
  api_url            = var.zcompute_private_api != null ? var.zcompute_private_api : var.zcompute_api
  is_agent           = true
  security_groups    = var.security_groups_ids
  subnet_ids         = var.private_subnets_ids
  template_file      = "${path.module}/templates/rke-agent-cloudinit.template.yaml"
  volume_size        = var.worker_volume_size

  max_size     = 10
  min_size     = var.workers_count
  desired_size = var.workers_count

  instance_tags = [
    {
      key   = "rke2.io/role"
      value = "worker"
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
  node_labels = []
}