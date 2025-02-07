variable "vpc_name" {
  type        = string
  description = "Display name for the VPC"
}

variable "vpc_cidr" {
  type        = string
  description = "IP CIDR configuration. ex: 10.0.0.0/16"
}

variable "vpc_cidr_public" {
  type        = string
  description = "IP CIDR configuration. ex: 10.0.0.0/17"
}

variable "vpc_cidr_private" {
  type        = string
  description = "IP CIDR configuration. ex: 10.0.128.0/17"
}

module "vpc" {
  source = "github.com/zadarastorage/terraform-zcompute-vpc?ref=main"
  # It's recommended to change `main` to a specific release version to prevent unexpected changes

  name            = var.vpc_name
  cidr            = var.vpc_cidr
  azs             = ["symphony"]
  public_subnets  = [var.vpc_cidr_public]
  private_subnets = [var.vpc_cidr_private]

  enable_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}
