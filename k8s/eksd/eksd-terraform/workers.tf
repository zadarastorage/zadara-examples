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
  source              = "./modules/asg"
  cluster_name        = var.environment
  group_name          = "${var.environment}-worker"
  image_id            = var.workers_eksd_ami == null ? var.eksd_ami : var.workers_eksd_ami
  instance_type       = var.workers_instance_type
  instance_profile    = local.workers_instance_profile
  key_pair_name       = var.workers_keyname
  eksd_masters_lb_url = local.lb_url
  eksd_token          = "${random_string.random_cluster_token_id.result}.${random_password.random_cluster_token_secret.result}"
  is_worker           = true
  security_groups     = [var.security_group_id]
  subnet_ids          = [var.private_subnet_id]
  volume_size         = var.workers_volume_size

  max_size     = var.workers_count + var.workers_addition
  min_size     = var.workers_count
  desired_size = var.workers_count

  root_ca_cert = var.root_ca_cert_path == "" ? "" : file(var.root_ca_cert_path)

  instance_tags = [
    {
      key   = "kubernetes.io/role"
      value = "worker"
    },
    {
      key   = "Environment"
      value = var.environment
    },
    {
      key   = "kubernetes.io/cluster/${var.environment}"
      value = "owned"
    },
    {
      key   = "k8s.io/cluster-autoscaler/${var.environment}"
      value = "owned"
    },
    {
      key   = "k8s.io/cluster-autoscaler/enabled"
      value = "owned"
    }
  ]

}
