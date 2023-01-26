locals {
  nlb_id = var.expose_k8s_api_publicly ? aws_lb.rke2_masters_public[0].id : aws_lb.rke2_masters_private[0].id
}

resource "aws_lb" "rke2_masters_private" {
  count              = var.expose_k8s_api_publicly ? 0 : 1
  name               = "rke2-masters"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.rke2_private.id]
  security_groups    = [
    aws_security_group.rke2_k8s.id,
  ]
  tags = {
    ManagedBy = "rke2 terraform"
  }

  depends_on = [aws_vpc.rke2_vpc, aws_subnet.rke2_public, aws_subnet.rke2_private]
}

resource "aws_lb" "rke2_masters_public" {
  count              = var.expose_k8s_api_publicly ? 1 : 0
  name               = "rke2-masters"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.rke2_public.id]
  security_groups    = [
    aws_security_group.rke2_k8s.id,
  ]
  tags = {
    ManagedBy = "rke2 terraform"
  }

  depends_on = [aws_vpc.rke2_vpc, aws_subnet.rke2_public, aws_subnet.rke2_private]
}