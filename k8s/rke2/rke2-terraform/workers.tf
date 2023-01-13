module "workers_instance_profile" {
  source = "./modules/instance-profile"
  iam_policy = local.iam_policy
  iam_role_name = "${var.environment}-workers-role"
  name = "${var.environment}-workers-instance-profile"
}

module "workers_asg" {
  source           = "./modules/asg"
  group_name       = "${var.cluster_name}-worker"
  image_id         = var.rke2_ami_id
  instance_type    = var.worker_instance_type
  instance_profile = module.workers_instance_profile.instance_profile_name
  key_pair_name    = var.worker_key_pair
  rke_cni          = var.k8s_cni
  rke_masters_lb_url   = local.lb_url
  rke_token        = random_uuid.random_cluster_id.result
  api_url          = var.zcompute_api
  is_agent         = true
  security_groups  = var.security_groups_ids
  subnet_ids       = var.private_subnets_ids
  template_file    = "${path.module}/templates/rke-agent-cloudinit.template.yaml"
  volume_size      = var.worker_volume_size

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
      key   = "kubernetes.io/cluster/${var.cluster_name}"
      value = "owned"
    }
  ]
  node_labels = []
}