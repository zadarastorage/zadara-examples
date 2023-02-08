variable "ami_id" {
  type        = string
  description = "ID (in AWS format) of the base image"
  default = ""
}

variable "zcompute_api" {
  type        = string
  description = "IP/DNS of the zCompute cluster API endpoint"
  default = "169.254.169.254"
}

variable "ssh_username" {
  type        = string
  description = "The ssh username for the packer builder"
  default = "centos"
}

variable "subnet_id" {
  type        = string
  description = "ID (in AWS format) of the subnet you want to provision the packer in"
  default = ""
}

variable "instance_type" {
  type        = string
  default     = "z4.large"
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

variable "rke2_k8s_version" {
  type        = string
  default     = "v1.23.4"
  description = "RKE2 k8s version"
}

variable "rke2_revision" {
  type        = string
  default     = "rke2r1"
  description = "RKE2 release revision"
}