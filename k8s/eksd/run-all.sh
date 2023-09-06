#!/bin/bash

set -ex

# Validate the number of arguments
if [ $# -ne 2 ]; then
    echo "Error: This script expects 2 arguments (and a pre-populated terraform.tfvars file)"
    echo "Usage: $0 access_key secret_key"
    exit 1
fi

# Populate variables
access_key=$1
secret_key=$2

# Step #1 - infrastructure automation
cd ./infra-terraform
terraform init --reconfigure
TF_VAR_cluster_access_key=$access_key TF_VAR_cluster_access_secret_id=$secret_key terraform apply -compact-warnings --auto-approve -var-file ../terraform.tfvars
TF_VAR_cluster_access_key=$access_key TF_VAR_cluster_access_secret_id=$secret_key terraform apply -compact-warnings --auto-approve -var-file ../terraform.tfvars
terraform output > ../infra.tfvars
api_endpoint=$(terraform output -raw api_endpoint)
bastion_ip=$(terraform output -raw bastion_ip)
masters_load_balancer_internal_dns=$(terraform output -raw masters_load_balancer_internal_dns)

# Step 1.5 - get NLB IPs
cd ..
bastion_user=$(echo var.bastion_user | terraform console | cut -d\" -f2)
bastion_keyfile=$(echo var.bastion_keyfile | terraform console | cut -d\" -f2)
./infra-terraform/get_loadbalancer.sh \
    $api_endpoint \
    $bastion_ip \
    $masters_load_balancer_internal_dns \
    $access_key \
    $secret_key \
    $bastion_user \
    $bastion_keyfile | tail -n 2 >> terraform.tfvars

# Step 2 - EKS-D deployment
cd ./eksd-terraform
terraform init --reconfigure
TF_VAR_cluster_access_key=$access_key TF_VAR_cluster_access_secret_id=$secret_key terraform apply --auto-approve -compact-warnings -var-file ../terraform.tfvars -var-file ../infra.tfvars
TF_VAR_cluster_access_key=$access_key TF_VAR_cluster_access_secret_id=$secret_key terraform apply --auto-approve -compact-warnings -var-file ../terraform.tfvars -var-file ../infra.tfvars
master_hostname=$(terraform output -raw master_hostname)

# Step 2.5 - Get kubeconfig
cd ..
masters_load_balancer_private_ip=$(echo var.masters_load_balancer_private_ip | terraform console | cut -d\" -f2)
masters_load_balancer_public_ip=$(echo var.masters_load_balancer_public_ip | terraform console | cut -d\" -f2)
master_keyfile=$(echo var.masters_keyfile | terraform console | cut -d\" -f2)
master_user="ubuntu"
./eksd-terraform/get_kubeconfig.sh \
    $master_hostname \
    $masters_load_balancer_private_ip \
    $masters_load_balancer_public_ip \
    $bastion_ip \
    $bastion_user \
    $bastion_keyfile \
    $master_user \
    $master_keyfile