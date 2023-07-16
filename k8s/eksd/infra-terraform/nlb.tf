locals {
  nlb_id = var.expose_k8s_api_publicly ? aws_lb.eksd_masters_public[0].id : aws_lb.eksd_masters_private[0].id
  nlb_private_dns = "elb-${local.nlb_id}.${var.dhcp_options_domain_name}"
  nlb_public_dns = var.expose_k8s_api_publicly ? aws_lb.eksd_masters_public[0].dns_name : aws_lb.eksd_masters_private[0].dns_name
}

resource "aws_lb" "eksd_masters_private" {
  count              = var.expose_k8s_api_publicly ? 0 : 1
  name               = "${var.environment}-eksd-masters"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.eksd_private.id]
  security_groups    = [
    aws_security_group.eksd_k8s.id,
  ]
  tags = {
    ManagedBy = "eksd terraform"
  }

  depends_on = [aws_route.igw, aws_route_table_association.private_to_private]
}

resource "aws_lb" "eksd_masters_public" {
  count              = var.expose_k8s_api_publicly ? 1 : 0
  name               = "${var.environment}-eksd-masters"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.eksd_public.id]
  security_groups    = [
    aws_security_group.eksd_k8s.id,
  ]
  tags = {
    ManagedBy = "eksd terraform"
  }

  depends_on = [aws_route.igw, aws_route_table_association.public_to_public]
}
