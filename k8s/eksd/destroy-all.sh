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
if test ! -f infra.tfvars; then
    echo "Error: Previous infra.tfvars file not found - nothing to remove"
    exit 1
fi

# Step 1 - EKS-D deployment
cd ./eksd-terraform
terraform destroy --auto-approve -compact-warnings -var-file ../terraform.tfvars -var-file ../infra.tfvars -var "cluster_access_key=$access_key" -var "cluster_access_secret_id=$secret_key"
rm -f terraform.tfstate*
cd ..

# Step 2 - infrastructure automation
cd ./infra-terraform
terraform destroy -compact-warnings --auto-approve -var-file ../terraform.tfvars -var "cluster_access_key=$access_key" -var "cluster_access_secret_id=$secret_key"
rm -f terraform.tfstate*
cd ..

# Step 3 - other leftovers
rm -f ./infra.tfvars
rm -f ./kubeconfig
