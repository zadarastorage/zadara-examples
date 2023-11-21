variable "group_name" {
  type        = string
  description = ""
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

variable "volume_type" {
  type        = string
  default     = null
  description = "VolumeType API alias (defaulting to null in order to preserve the zCompute default type) for EC2 instances"
}

variable "volume_size" {
  type        = string
  description = ""
}

variable "cluster_name" {
  type = string
}

variable "eksd_masters_lb_url" {
  type        = string
  default     = ""
  description = ""
}

variable "eksd_token" {
  type        = string
  description = ""
}

variable "eksd_certificate" {
  type        = string
  default     = ""
  description = ""
}

variable "is_worker" {
  type = bool
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
  type    = string
  default = "10.244.0.0/16"
}

variable "install_ebs_csi" {
  type    = bool
  default = true
}

variable "install_lb_controller" {
  type    = bool
  default = true
}

variable "install_autoscaler" {
  type    = bool
  default = true
}

variable "install_kasten_k10" {
  type    = bool
  default = false
}

variable "eksd_san" {
  default     = []
  type        = list(string)
  description = ""
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "security_groups" {
  type        = list(string)
  description = ""
}

variable "key_pair_name" {
  type        = string
  description = ""
}

variable "instance_type" {
  type        = string
  description = ""
}

variable "instance_profile" {
  type        = string
  description = ""
}

variable "image_id" {
  type        = string
  description = ""
}

variable "target_group_arns" {
  type        = list(string)
  default     = null
  description = ""
}

variable "subnet_ids" {
  type        = list(string)
  description = ""
}

variable "instance_tags" {
  type = list(object({
    key   = string
    value = string
  }))
}

variable "desired_size" {
  type        = number
  description = ""
}

variable "max_size" {
  type        = number
  description = ""
}

variable "min_size" {
  type        = number
  description = ""
}

variable "root_ca_cert" {
  type        = string
  default     = ""
  description = "The root certificate authority certificate of the cluster"
}
