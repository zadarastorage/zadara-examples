output "test_ip" {
  value = aws_eip.test-eip.public_ip
}

output "test_dns" {
  value = aws_eip.test-eip.public_dns
}

output "vpc_id" {
  value = aws_vpc.rke2_vpc.id
}

output "nlb_id" {
  value = local.nlb_id
}

output "nlb_private_dns" {
  value = local.nlb_private_dns
}

output "nlb_public_dns" {
  value = local.nlb_public_dns
}

output "public_subnet" {
  value = aws_subnet.rke2_public.id
}

output "private_subnet" {
  value = aws_subnet.rke2_private.id
}

output "k8s_sg" {
  value = aws_security_group.rke2_k8s.id
}

output "bastion_ip" {
  value = aws_eip.bastion.public_ip
}