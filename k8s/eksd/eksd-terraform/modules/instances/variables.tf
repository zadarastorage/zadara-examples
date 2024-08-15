variable "manage_instances_using_asg" {
  type = bool
  description = "Use AutoScalingGroup to manage instance's group or use regular instances"
  default = false
}

variable "keep_existing_asg_state" {
  type = bool
  description = "Do not change the existing AutoScalingGroup state"
  default = true
}

variable "migrate_from_asg" {
  type = bool
  description = "Use this flag to gracefully move from configuration using AutoScalingGroup to configuration using regular instances, this will keep the existing number of instances in the ASG which you can remove manually"
  default = true
}

variable "remove_master_asg" {
  type = bool
  description = "Delete/Do not create the master ASG group - for backward compatability this ASG is kept"
  default = false
}

variable "group_name" {
  type        = string
  description = ""
}

variable "asg_cooldown" {
  type        = number
  default     = null
  description = "Default cooldown period (scaling activity intervals - affecting scale down & up speeds)"
}

variable "asg_timeout" {
  type        = string
  default     = "30m"
  description = "Default timeout for ASG scaling to desired capacity"
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
  type        = object({
    name = string
    unique_id = string
  })
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

variable "backup_access_key_id" {
  type        = string
  sensitive   = true
  description = ""
  default     = ""
}

variable "backup_secret_access_key" {
  type        = string
  sensitive   = true
  description = ""
  default     = ""
}

variable "backup_region" {
  type        = string
  description = ""
  default     = "us-east-1"
}

variable "backup_endpoint" {
  type        = string
  description = ""
  default     = ""
}

variable "backup_bucket" {
  type        = string
  description = ""
  default     = ""
}

variable "backup_rotation" {
  type        = number
  description = ""
  default     = 100
}

variable "root_ca_cert" {
  type        = string
  default     = ""
  description = "The root certificate authority certificate of the cluster"
}
