output "get_kubeconfig_script" {
  description = "Pointer to script which can get the cluster's initial kubeconfig"
  value = "${path.module}/get_kubeconfig.sh ${var.environment}-master-1 ${var.masters_load_balancer_private_ip} ${var.masters_load_balancer_public_ip} ${var.bastion_ip} <bastion_user> <bastion_keypair> <master_keypair>"
}

