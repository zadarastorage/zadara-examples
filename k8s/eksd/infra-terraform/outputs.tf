output "environment" {
  value = var.environment
}

output "vpc_id" {
  value = aws_vpc.eksd_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.eksd_public.id
}

output "private_subnet_id" {
  value = aws_subnet.eksd_private.id
}

output "security_group_id" {
  value = aws_security_group.eksd_k8s.id
}

output "masters_load_balancer_id" {
  value = local.nlb_id
}

output "masters_load_balancer_internal_dns" {
  value = local.nlb_private_dns
}

output "bastion_ip" {
  value = aws_eip.bastion.public_ip
}
