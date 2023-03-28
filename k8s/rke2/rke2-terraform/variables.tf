variable "environment" {
  description = "Label to be used for tags and resource names for identification"
  default     = "k8s"
}

variable "zcompute_public_api" {
  type        = string
  description = "IP/DNS of the zCompute cluster API endpoint"
}

variable "zcompute_private_api" {
  type        = string
  default     = null
  description = "IP/DNS of the zCompute cluster API internal endpoint"
}

variable "rke2_ami_id" {
  description = "ID (in AWS format) of the AMI to be used for the kubernetes nodes"
}

variable "master_volume_size" {
  type = string
}

variable "worker_volume_size" {
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

variable "k8s_cni" {
  type        = string
  default     = "calico"
  description = "CNI options that rancher supports"

  validation {
    condition     = contains(["calico", "canal", "flannel"], var.k8s_cni)
    error_message = "Valid values for var: cni are (calico, canal, flannel)."
  }
}

variable "vpc_id" {
  type = string
}

variable "private_subnets_ids" {
  type = list(string)
}

variable "public_subnets_ids" {
  type = list(string)
}

variable "security_groups_ids" {
  type = list(string)
}

variable "worker_key_pair" {
  type = string
}

variable "master_key_pair" {
  type = string
}

variable "master_load_balancer_id" {
  type = string
}

variable "master_load_balancer_public_ip" {
  type    = string
  default = ""
}

variable "master_load_balancer_private_ip" {
  type    = string
  default = ""
}

variable "master_load_balancer_internal_dns" {
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
  description = "if not provided will be created by tf, be aware requires advanced IAM permissions"
  default     = null
}

variable "master_iam_role" {
  type        = string
  description = "if not provided will be created by tf, be aware requires advanced IAM permissions"
  default     = null
}

variable "worker_instance_profile" {
  type        = string
  description = "if not provided will be created by tf, be aware requires advanced IAM permissions"
  default     = null
}

variable "worker_iam_role" {
  type        = string
  description = "if not provided will be created by tf, be aware requires advanced IAM permissions"
  default     = null
}
