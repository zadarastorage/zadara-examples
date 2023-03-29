resource "aws_ec2_tag" "private" {
  count = length(var.private_subnets_ids)

  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
  resource_id = var.private_subnets_ids[count.index]
}

resource "aws_ec2_tag" "private_shared" {
  count = length(var.private_subnets_ids)

  key         = "kubernetes.io/cluster/${var.environment}"
  value       = "shared"
  resource_id = var.private_subnets_ids[count.index]
}

resource "aws_ec2_tag" "public" {
  count = length(var.public_subnets_ids)

  key         = "kubernetes.io/role/elb"
  value       = "1"
  resource_id = var.public_subnets_ids[count.index]
}

resource "aws_ec2_tag" "public_shared" {
  count = length(var.public_subnets_ids)

  key         = "kubernetes.io/cluster/${var.environment}"
  value       = "shared"
  resource_id = var.public_subnets_ids[count.index]
}

resource "aws_ec2_tag" "sg" {
  count = length(var.security_groups_ids)

  key = "kubernetes.io/cluster/${var.environment}"
  value = "shared"
  resource_id = var.security_groups_ids[count.index]
}

