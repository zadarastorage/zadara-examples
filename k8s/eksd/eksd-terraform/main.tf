resource "aws_ec2_tag" "private" {
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
  resource_id = var.private_subnet_id
}

resource "aws_ec2_tag" "private_shared" {
  key         = "kubernetes.io/cluster/${var.environment}"
  value       = "shared"
  resource_id = var.private_subnet_id
}

resource "aws_ec2_tag" "public" {
  key         = "kubernetes.io/role/elb"
  value       = "1"
  resource_id = var.public_subnet_id
}

resource "aws_ec2_tag" "public_shared" {
  key         = "kubernetes.io/cluster/${var.environment}"
  value       = "shared"
  resource_id = var.public_subnet_id
}

resource "aws_ec2_tag" "sg" {
  key         = "kubernetes.io/cluster/${var.environment}"
  value       = "shared"
  resource_id = var.security_group_id
}
