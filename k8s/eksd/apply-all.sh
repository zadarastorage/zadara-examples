#!/bin/bash

set -e

# Populate variables
access_key=$1
secret_key=$2

if [ $# -lt 2 ]; then
    echo "Warn: Did not receive access & secret keys as arguments, trying with environments variables AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY"
    access_key=$AWS_ACCESS_KEY_ID
    secret_key=$AWS_SECRET_ACCESS_KEY
    if [ ${#access_key} -lt 1 ] || [ ${#secret_key} -lt 1 ]; then
        echo "Error: Did not find AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY environment variables - exiting with error as no credentials found"
        exit 1
    fi
    echo "Info: Running without arguments - using AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY environment variables"
fi

# Step 0 - very basic check for leftovers...
if test -f infra.tfvars; then
    echo "Warn: Previous infra.tfvars file found - removing and re-applying all (otherwise please run destroy-all.sh before running apply-all.sh)"
    rm infra.tfvars
fi

# Step 1 - infrastructure automation
cd ./infra-terraform
terraform init --reconfigure
terraform apply -compact-warnings --auto-approve -var-file ../terraform.tfvars -var "cluster_access_key=$access_key" -var "cluster_access_secret_id=$secret_key"
terraform apply -compact-warnings --auto-approve -var-file ../terraform.tfvars -var "cluster_access_key=$access_key" -var "cluster_access_secret_id=$secret_key"
terraform output > ../infra.tfvars
bastion_ip=$(terraform output -raw bastion_ip)
masters_load_balancer_internal_dns=$(terraform output -raw masters_load_balancer_internal_dns)

# Step 1.5 - get NLB IPs
cd ..
bastion_user=$(echo var.bastion_user | terraform console | cut -d\" -f2)
bastion_keyfile=$(echo var.bastion_keyfile | terraform console | cut -d\" -f2)
./infra-terraform/get_loadbalancer.sh \
    $bastion_ip \
    $masters_load_balancer_internal_dns \
    $access_key \
    $secret_key \
    $bastion_user \
    $bastion_keyfile | tail -n 2 >> infra.tfvars

# Step 2 - EKS-D deployment
cd ./eksd-terraform
terraform init --reconfigure
terraform apply -compact-warnings --auto-approve -compact-warnings -var-file ../terraform.tfvars -var-file ../infra.tfvars -var "cluster_access_key=$access_key" -var "cluster_access_secret_id=$secret_key"
master_hostname=$(terraform output -raw master_hostname)

# Step 2.5 - Get (and output) kubeconfig
cd ..
masters_load_balancer_private_ip=$(echo var.masters_load_balancer_private_ip | terraform console -var-file infra.tfvars | tail -n 1 | cut -d\" -f2)
masters_load_balancer_public_ip=$(echo var.masters_load_balancer_public_ip | terraform console -var-file infra.tfvars | tail -n 1 | cut -d\" -f2)
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
echo "=========="
cat ./kubeconfig
