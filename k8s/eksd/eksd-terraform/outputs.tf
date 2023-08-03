output "master_hostname" {
  description = "master hostname (first master on the ASG)"
  value       = "${var.environment}-master-1"
}

output "apiserver_private" {
  description = "API server private endpoint (to be replaced with the public one)"
  value       = var.masters_load_balancer_private_ip
}

output "apiserver_public" {
  description = "API server public endpoint (to replace the private one on the original kubeconfig)"
  value       = var.masters_load_balancer_public_ip
}

output "bastion_ip" {
  description = "Bastion public IP"
  value       = var.bastion_ip
}

output "get_kubeconfig_script" {
  description = "Pointer to script which can get the cluster's initial kubeconfig"
  value       = "${path.module}/get_kubeconfig.sh ${var.environment}-master-1 ${var.masters_load_balancer_private_ip} ${var.masters_load_balancer_public_ip} ${var.bastion_ip} <bastion_user> <bastion_keypair> <master_user> <master_keypair>"
}

