variable "environment" {
  type    = string
  default = "k8s"
}

variable "zcompute_api" {
  type = string
}

variable "cluster_access_key" {
  type = string
}

variable "cluster_access_secret_id" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "192.168.0.0/16"
}

variable "public_cidr" {
  type    = string
  default = "192.168.0.0/24"
}

variable "private_cidr" {
  type    = string
  default = "192.168.2.0/23"
}

variable "dhcp_servers" {
  type    = list(string)
  default = ["8.8.8.8", "8.8.4.4"]
}

variable "dhcp_options_domain_name" {
  type    = string
  default = "symphony.local"
}

variable "expose_k8s_api_publicly" {
  type    = bool
  default = true
}

variable "bastion_key_name" {
  type    = string
}

variable "bastion_ami" {
  type = string
}

variable "bastion_instance_type" {
  type = string
  default = "z2.medium"
}