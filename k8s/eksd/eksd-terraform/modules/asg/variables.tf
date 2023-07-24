variable "group_name" {
  type        = string
  description = ""
}

variable "volume_type" {
  type        = string
  default     = "default"
  description = ""
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

variable "api_url" {
  type = string
}

variable "pod_network" {
  type = string
  default = "10.244.0.0/16"
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

variable "target_group_arn" {
  type        = string
  default     = ""
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