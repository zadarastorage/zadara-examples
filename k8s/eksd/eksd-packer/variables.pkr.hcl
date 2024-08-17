variable "ami_id" {
  type        = string
  description = "ID (in AWS format) of the base image"
  default = ""
}

variable "api_endpoint" {
  type        = string
  description = "IP/DNS of the zCompute cluster API endpoint"
  default = "169.254.169.254"
}

variable "ssh_username" {
  type        = string
  description = "The ssh username for the packer builder"
  default = "ubuntu"
}

variable "subnet_id" {
  type        = string
  description = "ID (in AWS format) of the subnet you want to provision the packer in"
  default = ""
}

variable "instance_type" {
  type        = string
  default     = "z8.large"
  description = "The builder instance type"
}

variable "private_keypair_path" {
  type        = string
  default     = ""
  description = "Keypair private key path"
}

variable "bastion_public_ip" {
  type        = string
  description = "Bastion IP for ssh"
  default = ""
}

variable "ssh_bastion_username" {
  type        = string
  description = "Bastion ssh username"
  default = ""
}

variable "ssh_keypair_name" {
  type        = string
  description = "Keypair name to use for the packer builder"
  default = ""
}

variable "eksd_k8s_version" {
  type        = string
  default     = "1-29"
  description = "EKS-D k8s version"
}

variable "eksd_revision" {
  type        = string
  default     = "3"
  description = "EKS-D release revision"
}

variable "use_latest_addons" {
  type        = string
  default     = "false"
  description = "Whether to use the latest addons or the baked-in versions from the script"
}

variable "cloud_controller_addon_chart_version" {
  type        = string
  default     = ""
  description = "CloudController addon chart version - if not set will use the baked-in version for the EKSD version"
}

variable "aws_ebs_csi_driver_chart_version" {
  type        = string
  default     = ""
  description = "EBS CSI driver chart version - if not set will use the baked-in version for the EKSD version"
}

variable "aws_load_balancer_controller_chart_version" {
  type        = string
  default     = ""
  description = "LoadBalancer Controller addon chart version - if not set will use the baked-in version for the EKSD version"
}

variable "cluster_auto_scaler_chart_version" {
  type        = string
  default     = ""
  description = "Cluster auto scaler chart version - if not set will use the baked-in version for the EKSD version"
}

variable "kasten_k10_chart_version" {
  type        = string
  default     = ""
  description = "Kasten K10 addon chart version - if not set will use the baked-in version for the EKSD version"
}