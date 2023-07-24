variable "environment" {
  description = "Cluster name label to be used in tags, as well as a prefix for various resource names (for example prevent IAM resources overlap)"
  default     = "k8s"
}

variable "zcompute_api" {
  type        = string
  description = "IP/DNS of the zCompute cluster API endpoint"
}

variable "zcompute_private_api" {
  type        = string
  default     = null
  description = "IP/DNS of the zCompute cluster API internal endpoint"
}

variable "eksd_ami_id" {
  description = "ID (in AWS format) of the AMI to be used for the kubernetes nodes"
}

variable "masters_volume_size" {
  type = string
}

variable "workers_volume_size" {
  type = string
}

variable "masters_count" {
  type = number
}

variable "workers_count" {
  type = number
}

variable "master_instance_type" {
  default     = "z4.xlarge"
  description = "K8s server (master) node instance type"
}

variable "worker_instance_type" {
  default     = "z4.xlarge"
  description = "K8s agent (worker) node instance type"
}

variable "taint_masters" {
  default     = true
  type        = bool
  description = "If set to false, user workloads would run on K8s master nodes"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "workers_key_pair" {
  type = string
}

variable "masters_key_pair" {
  type = string
}

variable "masters_load_balancer_id" {
  type = string
}

variable "masters_load_balancer_public_ip" {
  type    = string
  default = ""
}

variable "masters_load_balancer_private_ip" {
  type    = string
  default = ""
}

variable "masters_load_balancer_internal_dns" {
  type    = string
  default = ""
}

variable "k8s_api_server_port" {
  type    = number
  default = 6443
}

variable "cluster_access_key" {
  type      = string
  sensitive = true
}

variable "cluster_access_secret_id" {
  type      = string
  sensitive = true
}

variable "master_instance_profile" {
  type        = string
  description = "if not provided will be created by tf, be aware requires IAMFullAccess permission"
  default     = null
}

variable "master_iam_role" {
  type        = string
  description = "if not provided will be created by tf, be aware requires IAMFullAccess permission"
  default     = null
}

variable "worker_instance_profile" {
  type        = string
  description = "if not provided will be created by tf, be aware requires IAMFullAccess permission"
  default     = null
}

variable "worker_iam_role" {
  type        = string
  description = "if not provided will be created by tf, be aware requires IAMFullAccess permission"
  default     = null
}
