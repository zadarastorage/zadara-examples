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

# Step 1 - EKS-D deployment
cd ./eksd-terraform
terraform destroy --auto-approve -compact-warnings -var-file ../terraform.tfvars -var-file ../infra.tfvars -var "cluster_access_key=$access_key" -var "cluster_access_secret_id=$secret_key"
rm -f terraform.tfstate terraform.tfstate.backup
cd ..

# Step 2 - infrastructure automation
cd ./infra-terraform
terraform destroy -compact-warnings --auto-approve -var-file ../terraform.tfvars -var "cluster_access_key=$access_key" -var "cluster_access_secret_id=$secret_key"
rm -f terraform.tfstate terraform.tfstate.backup
cd ..

# Step 3 - other leftovers
rm -f ./infra.tfvars
rm -f ./kubeconfig
