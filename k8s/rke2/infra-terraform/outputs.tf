output "vpc_id" {
  value = aws_vpc.rke2_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.rke2_public.id
}

output "private_subnet_id" {
  value = aws_subnet.rke2_private.id
}

output "security_groups_id" {
  value = aws_security_group.rke2_k8s.id
}

output "master_load_balancer_id" {
  value = local.nlb_id
}

output "master_load_balancer_internal_dns" {
  value = local.nlb_private_dns
}

output "master_load_balancer_external_dns" {
  value = local.nlb_public_dns
}

output "bastion_ip" {
  value = aws_eip.bastion.public_ip
}
