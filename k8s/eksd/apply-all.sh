#!/bin/bash
set -e

ORIGINAL_COMMAND=$0
usage () {
    echo "$1"
    echo "USAGE: $ORIGINAL_COMMAND [options]"
    echo "  [-p|--state-path {path}] Root directory for terraform state files"
    echo "  [-i|--infra-only] Apply (or re-apply) only the infra part"
    echo "  [-k|--eksd-only] Apply (or re-apply) only the EKSD part"
    echo "  [--initialize-state] Initialize state files - this will delete existing state files!!!"
    echo "  [--no-auto-approve] Let terraform ask for plan apply approval"
    echo "  [-h|--help] Usage message"
    echo ""
    echo "    either (AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY) or (TF_VAR_cluster_access_secret_id/TF_VAR_cluster_access_key)"
    echo "    environment variable pair are expected to contain the cloud access secret id and access secret key"
}

INFRA_ONLY="0"
EKSD_ONLY="0"
AUTO_APPROVE="--auto-approve"
INITIALIZE_STATE=""

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
        --initialize-state)
        INITIALIZE_STATE="-reconfigure"
        echo "WARNING: State files will be deleted - press Ctrl-C now to cancel"
        for x in $(seq 1 10); do echo -n .; sleep 1; done; echo
        shift # past argument
        ;;
        -i|--infra-only)
        INFRA_ONLY="1"
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
else
  cp -f variables.tf "${STATE_PATH}/"
fi

INFRA_STATE_PATH="${STATE_PATH}/infra-terraform/terraform.tfstate"
INFRA_BACKEND_CFG="${STATE_PATH}/infra-terraform-backend.hcl"

EKSD_STATE_PATH="${STATE_PATH}/eksd-terraform/terraform.tfstate"
EKSD_BACKEND_CFG="${STATE_PATH}/eksd-terraform-backend.hcl"

INFRA_TFVARS_PATH="${STATE_PATH}/infra.tfvars"
TERRAFORM_TFVARS_PATH="${STATE_PATH}/terraform.tfvars"

if test ! -f "${TERRAFORM_TFVARS_PATH}"; then
    echo "ERROR: ${TERRAFORM_TFVARS_PATH} file not found - cannot continue."
    echo "       Copy the 'terraform.tfvars.template' file to ${TERRAFORM_TFVARS_PATH} and edit the parameters"
    exit 1
fi

mkdir -p "${STATE_PATH}/infra-terraform"
mkdir -p "${STATE_PATH}/eksd-terraform"

terraform_init() {
TF_INIT_COMMAND="terraform init ${INITIALIZE_STATE}"
BACKEND_FILE="backend.tf"
    if [ -f "${BACKEND_FILE}" ]; then
        echo "Custom backend config has been found!"
        $TF_INIT_COMMAND
    else
        echo "WARN: Local backend has been configured because no backend.tf file has been found. It is advised to use a remote backend for production use!"
        cat > "${INFRA_BACKEND_CFG}" <<EOF
terraform {
    backend "local" {
        path = "${INFRA_STATE_PATH}"
    }
}
EOF
        cat > "${EKSD_BACKEND_CFG}" <<EOF
terraform {
    backend "local" {
        path = "${INFRA_STATE_PATH}"
    }
}
EOF
        $TF_INIT_COMMAND
    fi
}

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

# Step 0 - very basic check for potential issues...
if [[ "$TF_VAR_backup_access_key_id"=="" || "$TF_VAR_backup_secret_access_key"=="" || "$TF_VAR_backup_bucket"=="" ]]; then
    echo "WARN: No environment variables found for setting up extrnal ETCD backup (TF_VAR_backup_bucket, etc.) - unless added to the eksd-terraform project variable file or via zadara-backup-export secret then this cluster might not be restorable in case of a control-plane failure"
fi

if [ "${EKSD_ONLY}" != "1" ]
then
  # Make sure the infra result file does not exists, and remove if it is
  if test -f "${INFRA_TFVARS_PATH}"
  then
      echo "WARN: Previous ${INFRA_TFVARS_PATH} file found - removing and re-applying all (otherwise please run destroy-all.sh before running apply-all.sh)"
      rm "${INFRA_TFVARS_PATH}"
  fi
  # Step 1 - infrastructure automation
  cd ./infra-terraform
  terraform_init
  TF_VAR_cluster_access_key=$access_key TF_VAR_cluster_access_secret_id=$secret_key \
      terraform apply -compact-warnings ${AUTO_APPROVE} -var-file "${TERRAFORM_TFVARS_PATH}"
  TF_VAR_cluster_access_key=$access_key TF_VAR_cluster_access_secret_id=$secret_key \
      terraform apply -compact-warnings ${AUTO_APPROVE} -var-file "${TERRAFORM_TFVARS_PATH}"
  terraform output > "${INFRA_TFVARS_PATH}"
  bastion_ip=$(terraform output -raw bastion_ip)
  masters_load_balancer_internal_dns=$(terraform output -raw masters_load_balancer_internal_dns)

  # Step 1.5 - get NLB IPs
  cd ..
  bastion_user=$(echo var.bastion_user | terraform console -var-file "${TERRAFORM_TFVARS_PATH}" | cut -d\" -f2)
  bastion_keyfile=$(echo var.bastion_keyfile | terraform console -var-file "${TERRAFORM_TFVARS_PATH}" | cut -d\" -f2)
  sed -r "/masters_load_balancer_/d" "${INFRA_TFVARS_PATH}"
  TF_VAR_cluster_access_key=$access_key TF_VAR_cluster_access_secret_id=$secret_key ./infra-terraform/get_loadbalancer.sh \
      -l $masters_load_balancer_internal_dns \
      -b $bastion_ip \
      -u $bastion_user \
      -k $bastion_keyfile | grep -e masters_load_balancer_ | tail -n 2 >> "${INFRA_TFVARS_PATH}"
else
  # Check all required files from infra stage exists
  if test ! -f ${INFRA_TFVARS_PATH}
  then
      echo "ERROR: ${INFRA_TFVARS_PATH} file not found - cannot continue."
      echo "       make sure you run the infra stage first"
      exit 1
  fi
fi

if [ "${INFRA_ONLY}" == "1" ]
then
  exit 0
fi

# Step 2 - EKS-D deployment
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
    terraform apply -compact-warnings ${AUTO_APPROVE} -compact-warnings -var-file "${TERRAFORM_TFVARS_PATH}" -var-file "${INFRA_TFVARS_PATH}"
master_hostname=$(terraform output -raw master_hostname)
cd ..

# Step 2.5 - Get (and output) kubeconfig
masters_load_balancer_private_ip=$(echo var.masters_load_balancer_private_ip | terraform console -var-file "${INFRA_TFVARS_PATH}" | tail -n 1 | cut -d\" -f2)
masters_load_balancer_public_ip=$(echo var.masters_load_balancer_public_ip | terraform console -var-file "${INFRA_TFVARS_PATH}" | tail -n 1 | cut -d\" -f2)
master_keyfile=$(echo var.masters_keyfile | terraform console -var-file "${TERRAFORM_TFVARS_PATH}" | cut -d\" -f2)
master_user="ubuntu"
./eksd-terraform/get_kubeconfig.sh \
    $master_hostname \
    $masters_load_balancer_private_ip \
    $masters_load_balancer_public_ip \
    $bastion_ip \
    $bastion_user \
    $bastion_keyfile \
    $master_user \
    $master_keyfile \
    "${STATE_PATH}/kubeconfig"
echo "=========="
cat "${STATE_PATH}/kubeconfig"
