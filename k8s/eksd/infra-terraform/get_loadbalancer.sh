#!/bin/bash
set -e

ORIGINAL_COMMAND=$0
usage () {
    echo "$1"
    echo "USAGE: $ORIGINAL_COMMAND [options]"
    echo "  [-l|--loadbalancer-dns] DNS name of the load-balancer"
    echo "  [-b|--bastion-ip] IP address of the bastion VM"
    echo "  [-u|--bastion-user] Bastion user name for login"
    echo "  [-k|--bastion-key-file] Bastion SSH key file for login"
    echo "  [-h|--help] Usage message"
    echo ""
    echo "    either (AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY) or (TF_VAR_cluster_access_secret_id/TF_VAR_cluster_access_key)"
    echo "    environment variable pair are expected to contain the cloud access secret id and access secret key"
    exit 1
}


while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -b|--bastion-ip)
        bastion_ip="$2"
        shift # past argument
        shift # past value
        ;;
        -l|--loadbalancer-dns)
        loadbalancer_dns="$2"
        shift # past argument
        shift # past value
        ;;
        -u|--bastion-user)
        bastion_user="$2"
        shift # past argument
        shift # past value
        ;;
        -k|--bastion-key-file)
        bastion_key="$2"
        shift # past argument
        shift # past value
        ;;
        -h|--help)
        usage "get the external IP for external DNS name of a load-balancer"
        ;;
        *)
        shift
        ;;
    esac
done


# Make sure all variables are populated
if [[ -z "${bastion_ip}" ]]
then
   usage "Bastion IP was not passed"
fi
if [[ -z "${loadbalancer_dns}" ]]
then
   usage "Load-balancer DNS was not passed"
fi
if [[ -z "${bastion_user}" ]]
then
   usage "Bastion username was not passed"
fi
if [[ -z "${bastion_key}" ]]
then
   usage "Bastion Key file was not passed"
fi

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

# Get the private IP based on the private DNS of the LoadBalancer
private_ip=$(ssh -i $bastion_key -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "getent hosts $loadbalancer_dns | awk '{ print \$1 }'")

echo Install the AWS CLI on the bastion VM
ssh -T -i $bastion_key -o StrictHostKeyChecking=no $bastion_user@$bastion_ip<< EOF
if ! which aws
then
  if which yum
  then
    sudo yum install -y -q unzip jq
  elif which apt-get
  then
    sudo apt-get install -y -q unzip jq
  fi
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -qo awscliv2.zip
  sudo ./aws/install 1>/dev/null || true
fi
EOF

# Get the internal API endpoint
api_endpoint=$(ssh -i $bastion_key -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "\
    curl -s http://169.254.169.254/openstack/latest/meta_data.json | \
    jq -c '.cluster_url'" | cut -d\" -f2)

# Invoke AWS CLI to get the public IP of the LoadBalancer
public_ip=$(ssh -i $bastion_key -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "\
    AWS_ACCESS_KEY_ID=$access_key AWS_SECRET_ACCESS_KEY=$secret_key \
    aws ec2 describe-network-interfaces \
    --endpoint-url $api_endpoint/api/v2/aws/ec2 \
    --filter 'Name=addresses.private-ip-address,Values=$private_ip' \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text")

# Uninstall the AWS CLI from the bastion VM
ssh -T -i $bastion_key -o StrictHostKeyChecking=no $bastion_user@$bastion_ip<< EOF
sudo rm -f /usr/local/bin/aws
sudo rm -f /usr/local/bin/aws_completer
sudo rm -rf /usr/local/aws-cli
rm -rf ~/aws
rm -f ~/awscliv2.zip
EOF

echo "masters_load_balancer_private_ip = \"$private_ip\""
echo "masters_load_balancer_public_ip = \"$public_ip\""