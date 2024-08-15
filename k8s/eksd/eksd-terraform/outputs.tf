locals {
  master_hostname = var.manage_masters_using_asg ? "${module.masters_instances.group_name}-1" : "${module.masters_instances.group_name}-sa-1"
}
output "master_hostname" {
  description = "master hostname (first master on the ASG)"
  value       = local.master_hostname
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

output "x_kubeconfig_script" {
  description = "Pointer to script which can get the cluster's initial kubeconfig"
  value       = "${path.module}/get_kubeconfig.sh ${local.master_hostname} ${var.masters_load_balancer_private_ip} ${var.masters_load_balancer_public_ip} ${var.bastion_ip} <bastion_user> <bastion_keypair> <master_user> <master_keypair>"
}

output "instance_ids" {
  description = "List of instances IDs of the created master VMs when not using ASG to manage them"
  value = module.masters_instances.instance_ids
}
