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

variable "bastion_keyname" {
  type        = string
  default     = "bastion"
  description = "Key-Pair name for the bastion VM"
}

variable "bastion_keyfile" {
  type        = string
  default     = "./bastion.pem"
  description = "Relative filepath for the bastion key-pair private key file"
}

variable "eksd_ami" {
  type        = string
  default     = "ami-..."
  description = "AWS id of the EKS-D pre-baked image"
}

variable "bastion_ami" {
  type        = string
  default     = "ami-..."
  description = "AWS id of the bastion base image (Ubuntu 22.04 or CentOS 7)"
}

variable "bastion_user" {
  type        = string
  default     = "ubuntu"
  description = "Username for the bastion VM (depending on the base image, this can be either ubuntu or centos)"
}

variable "masters_keyname" {
  type        = string
  default     = "masters"
  description = "Key-Pair name for the masters VMs"
}

variable "masters_keyfile" {
  type        = string
  default     = "./masters.pem"
  description = "Relative filepath for the masters key-pair private key file"
}

variable "workers_keyname" {
  type        = string
  default     = "workers"
  description = "Key-Pair name for the workers VMs"
}

variable "workers_keyfile" {
  type        = string
  default     = "./workers.pem"
  description = "Relative filepath for the workers key-pair private key file"
}

variable "masters_load_balancer_private_ip" {
  type        = string
  default     = ""
  description = "Private IP of the NLB - to be populated automatically"
}

variable "masters_load_balancer_public_ip" {
  type        = string
  default     = ""
  description = "Public IP of the NLB - to be populated automatically"
}
