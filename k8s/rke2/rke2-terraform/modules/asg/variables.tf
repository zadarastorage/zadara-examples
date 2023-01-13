variable "group_name" {
  type        = string
  description = ""
}

variable "volume_type" {
  type        = string
  default     = null
  description = ""
}

variable "volume_size" {
  type        = string
  description = ""
}

variable "rke_cni" {
  type        = string
  description = "CNI options that rancher supports"

  validation {
    condition     = contains(["calico", "canal", "flannel"], var.rke_cni)
    error_message = "Valid values for var: cni are (calico, canal, flannel)."
  }
}

variable "rke_masters_lb_url" {
  type        = string
  default     = ""
  description = ""
}

variable "rke_token" {
  type        = string
  description = ""
}

variable "template_file" {
  type        = string
  description = ""
}

variable "is_agent" {
  type = bool
}

variable "api_url" {
  type = string
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

variable "target_groups_arns" {
  type        = list(string)
  default     = []
  description = ""
}

variable "subnet_ids" {
  type        = list(string)
  description = ""
}

variable "taint_servers" {
  default     = false
  type        = bool
  description = "Set True for master nodes"
}

variable "rke_san" {
  default     = []
  type        = list(string)
  description = ""
}

variable "instance_tags" {
  type = list(object({
    key   = string
    value = string
  }))
}

variable "node_labels" {
  type    = list(string)
  default = []
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