variable "api_endpoint" {
  type        = string
  description = "IP/DNS of the zCompute cluster API endpoint"
}

variable "cluster_access_key" {
  type      = string
  sensitive = true
}

variable "cluster_access_secret_id" {
  type      = string
  sensitive = true
}

variable "environment" {
  type        = string
  default     = "k8s"
  description = "Kubernetes cluster name (to be used in tags as well as Kubernetes-related resource prefix)"
}

variable "eksd_ami" {
  type        = string
  description = "AWS id of the EKS-D image to be used for all Kubernetes nodes"
}

variable "masters_eksd_ami" {
  type        = string
  default     = null
  description = "AWS id of the EKS-D image to be used for all control-plane Kubernetes nodes"
}

variable "workers_eksd_ami" {
  type        = string
  default     = null
  description = "AWS id of the EKS-D image to be used for all data-plane Kubernetes nodes"
}

variable "masters_volume_size" {
  type    = string
  default = "50"
}

variable "workers_volume_size" {
  type    = string
  default = "100"
}

variable "masters_count" {
  type        = number
  default     = 1
  description = "Initial masters ASG capacity"
}

variable "masters_addition" {
  type        = number
  default     = 0
  description = "Maximal increased capacity to masters ASG above initial size"
}

variable "workers_count" {
  type        = number
  default     = 1
  description = "Initial workers ASG capacity"
}

variable "workers_addition" {
  type        = number
  default     = 3
  description = "Maximal increased capacity to workers ASG above initial size"
}

variable "masters_instance_type" {
  default     = "z4.large"
  description = "Kubernetes control-plane (master) node instance type - etcd recommends L-XL, kubeadm will not allow M"
}

variable "workers_instance_type" {
  default     = "z8.large"
  description = "Kubernetes data-plane (worker) node instance type - depends on the workload, kubeadm will not allow M"
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

variable "bastion_ip" {
  description = "Bastion public IP - only required if you want to fetch the initial kubeconfig"
  type        = string
  default     = ""
}

variable "workers_keyname" {
  type = string
}

variable "masters_keyname" {
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

variable "master_instance_profile" {
  type        = string
  description = "If not provided will be created by terraform, be aware - requires IAMFullAccess permission"
  default     = null
}

variable "master_iam_role" {
  type        = string
  description = "If not provided will be created by terraform, be aware - requires IAMFullAccess permission"
  default     = null
}

variable "worker_instance_profile" {
  type        = string
  description = "If not provided will be created by terraform, be aware - requires IAMFullAccess permission"
  default     = null
}

variable "worker_iam_role" {
  type        = string
  description = "If not provided will be created by terraform, be aware - requires IAMFullAccess permission"
  default     = null
}

variable "cni_provider" {
  type        = string
  default     = "flannel"
  description = "CNI provider - choose from flannel, calico or cilium (experimental)"
  validation {
    condition     = contains(["flannel", "calico", "cilium"], var.cni_provider)
    error_message = "Valid values for var: cni_provider are (flannel, calico, cilium)."
  }
}

variable "pod_network" {
  type        = string
  description = "CIDR for internal Kubernetes pods network"
  default     = "10.244.0.0/16"
}

variable "ebs_csi_volume_type" {
  type        = string
  default     = "gp2"
  description = "VolumeType API alias (defaulting to gp2 in order to align with zCompute default VolumeType) for EBS CSI PVs"
  validation {
    condition     = contains(["io1", "io2", "gp2", "gp3", "sc1", "st1", "standard", "sbp1", "sbg1"], var.ebs_csi_volume_type)
    error_message = "Valid values for var: ebs_csi_volume_type are (io1, io2, gp2, gp3, sc1, st1, standard, sbp1, sbg1)."
  }
}

variable "install_ebs_csi" {
  type        = bool
  default     = true
  description = "Addon: EBS CSI driver"
}

variable "install_lb_controller" {
  type        = bool
  default     = true
  description = "Addon: AWS Load Balancer Controller"
}

variable "install_autoscaler" {
  type        = bool
  default     = true
  description = "Addon: Cluster Autoscaler"
}

variable "install_kasten_k10" {
  type        = bool
  default     = false
  description = "Addon: Kasten K10"
}

variable "root_ca_cert_path" {
  type        = string
  default     = ""
  description = "Path to the root certificate authority certificate of the cluster"
}
