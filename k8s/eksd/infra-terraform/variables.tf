variable "api_endpoint" {
  type        = string
  description = "IP/DNS of the zCompute cluster API endpoint"
}

variable "cluster_access_key" {
  type = string
}

variable "cluster_access_secret_id" {
  type = string
}

variable "environment" {
  type        = string
  default     = "k8s"
  description = "Kubernetes cluster name (to be used in tags as well as Kubernetes-related resource prefix)"
}

variable "vpc_cidr" {
  type        = string
  default     = "192.168.0.0/16"
  description = "Dedicated VPC CIDR"
}

variable "public_cidr" {
  type        = string
  default     = "192.168.0.0/24"
  description = "Public subnet's CIDR (to be used by the bastion and potentially the Kubernetes API Server endpoint)"
}

variable "private_cidr" {
  type        = string
  default     = "192.168.2.0/23"
  description = "Private subnet's CIDR (to be used by the Kubernetes nodes)"
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
  type        = bool
  default     = true
  description = "Whether or not to expose the Kubernetes API Server endpoint with a public IP"
}

variable "bastion_keyname" {
  type        = string
  description = "Key-pair name to be used in order to access the bastion"
}

variable "bastion_ami" {
  type        = string
  description = "AWS id of the image to be used by the bastion instance"
}

variable "bastion_instance_type" {
  type    = string
  default = "z2.medium"
}

variable "root_ca_cert_path" {
  type        = string
  default     = ""
  description = "Path to the root certificate authority certificate of the cluster"
}
