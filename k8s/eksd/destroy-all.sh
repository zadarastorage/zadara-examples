#!/bin/bash

set -e

ORIGINAL_COMMAND=$0
usage () {
    echo "$1"
    echo "USAGE: $ORIGINAL_COMMAND [options]"
    echo "  [-p|--state-path {path}] Root directory for terraform state files"
    echo "  [-k|--no-auto-approve] Let terraform ask for plan destroy approval"
    echo "  [-k|--eksd-only] Destroy only the EKSD part"
    echo "  [-h|--help] Usage message"
    echo ""
    echo "    either (AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY) or (TF_VAR_cluster_access_secret_id/TF_VAR_cluster_access_key)"
    echo "    environment variable pair are expected to contain the cloud access secret id and access secret key"
}

AUTO_APPROVE="--auto-approve"

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -p|--state-path)
        STATE_PATH="$2"
        shift # past argument
        shift # past value
        ;;
        -n|--no-auto-approve)
        AUTO_APPROVE=""
        shift # past argument
        ;;
        -k|--eksd-only)
        EKSD_ONLY="1"
        shift # past argument
        ;;
        -h|--help)
        usage "Help:"
        shift
        ;;
        *)
        shift
        ;;
    esac
done

if [[ -z "${STATE_PATH}" ]]
then
  STATE_PATH="${PWD}"
fi

INFRA_STATE_PATH="${STATE_PATH}/infra-terraform/terraform.state"

EKSD_STATE_PATH="${STATE_PATH}/eksd-terraform/terraform.state"

INFRA_TFVARS_PATH="${STATE_PATH}/infra.tfvars"
TERRAFORM_TFVARS_PATH="${STATE_PATH}/terraform.tfvars"

terraform_init() {
TF_INIT_COMMAND="terraform init"
BACKEND_FILE="backend.tf"

    if [ -f "${BACKEND_FILE}" ]; then
        echo "Custom backend config has been found!"
        $TF_INIT_COMMAND
    else
        echo "Local backend config has been found!"
        $TF_INIT_COMMAND
    fi
}
if ! test -f "${TERRAFORM_TFVARS_PATH}"
then
  echo "ERROR: ${TERRAFORM_TFVARS_PATH} or ${INFRA_TFVARS_PATH} files not found - cannot continue."
  echo "       was the apply-all.sh script run with with the provided state-path"
  exit 1
fi

# Populate ACCESS KEY variables
if [[ ! -z "${AWS_ACCESS_KEY_ID}" ]]
then
    access_key="${AWS_ACCESS_KEY_ID}"
    secret_key="${AWS_SECRET_ACCESS_KEY}"
elif [[ ! -z "${TF_VAR_cluster_access_key}" ]]
then
    access_key="${TF_VAR_cluster_access_key}"
    secret_key="${TF_VAR_cluster_access_secret_id}"
else
    usage "ERROR: Failed to extract cloud access key from (AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY) or (TF_VAR_cluster_access_secret_id/TF_VAR_cluster_access_key)"
fi
if [ ${#access_key} -lt 1 ] || [ ${#secret_key} -lt 1 ]; then
    echo "ERROR: Did not find AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY environment variables - exiting with error as no credentials found"
    exit 1
fi

# Step 0 - very basic check for leftovers...
if test ! -f "${INFRA_TFVARS_PATH}"; then
    echo "ERROR: Previous infra.tfvars file not found - nothing to remove"
    exit 1
fi

# Step 1 - EKS-D deployment
cd ./eksd-terraform
terraform_init
# Initialize parameters
bastion_user=$(echo var.bastion_user | terraform console -var-file "${TERRAFORM_TFVARS_PATH}" | tail -n 1 |cut -d\" -f2)
bastion_keyfile=$(echo var.bastion_keyfile | terraform console -var-file "${TERRAFORM_TFVARS_PATH}" | tail -n 1 |cut -d\" -f2)
bastion_ip=$(cd ../infra-terraform; terraform output -raw bastion_ip)
bastion_user=$(echo var.bastion_user | terraform console -var-file "${TERRAFORM_TFVARS_PATH}" | tail -n 1 |cut -d\" -f2)
bastion_keyfile=$(echo var.bastion_keyfile | terraform console -var-file "${TERRAFORM_TFVARS_PATH}" | tail -n 1 |cut -d\" -f2)
masters_asg_name=$(echo module.masters_instances.group_name | terraform console -var-file "${TERRAFORM_TFVARS_PATH}" | tail -n 1 | cut -d\" -f2)

# Check if ASG exists
masters_asg_exists=$(TF_VAR_cluster_access_key=$access_key TF_VAR_cluster_access_secret_id=$secret_key ./get_existing_asg.sh \
    -l $masters_asg_name \
    -b $bastion_ip \
    -u $bastion_user \
    -k $bastion_keyfile | grep -e master_auto_scaling_group_exists | tail -n 1 | awk '{print $2}')

TF_VAR_master_auto_scaling_group_exists=${masters_asg_exists} TF_VAR_cluster_access_key=$access_key TF_VAR_cluster_access_secret_id=$secret_key \
    terraform destroy ${AUTO_APPROVE} -compact-warnings -var-file "${TERRAFORM_TFVARS_PATH}" -var-file "${INFRA_TFVARS_PATH}"
rm -f "${EKSD_STATE_PATH}" "${EKSD_STATE_PATH}.backup"
rm -f "${STATE_PATH}/kubeconfig"
cd ..

if [ "${EKSD_ONLY}" == "1" ]
then
  exit 0
fi

# Step 2 - infrastructure automation
cd ./infra-terraform
terraform_init
TF_VAR_cluster_access_key=$access_key TF_VAR_cluster_access_secret_id=$secret_key \
    terraform destroy -compact-warnings ${AUTO_APPROVE} -var-file "${TERRAFORM_TFVARS_PATH}"
rm -f "${INFRA_STATE_PATH}" "${INFRA_STATE_PATH}.backup"
cd ..
