#!/bin/bash
set -e

ORIGINAL_COMMAND=$0
usage () {
    echo "$1"
    echo "USAGE: $ORIGINAL_COMMAND [options]"
    echo "  [-l|--asg-name] AutoScalingGroup name"
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
        -l|--asg-name)
        asg_name="$2"
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
        usage "Check if a specific ASG group exists"
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
if [[ -z "${asg_name}" ]]
then
   usage "AutoScalingGroup name was not passed"
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
  sudo ./aws/install 2>/dev/null || true
fi
EOF

# Get the internal API endpoint
api_endpoint=$(ssh -i $bastion_key -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "\
    curl -s http://169.254.169.254/openstack/latest/meta_data.json | \
    jq -c '.cluster_url'" | cut -d\" -f2)

# Invoke AWS CLI to get the public IP of the LoadBalancer
reported_asg_name=$(ssh -i $bastion_key -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "\
    AWS_ACCESS_KEY_ID=$access_key AWS_SECRET_ACCESS_KEY=$secret_key \
    aws autoscaling --endpoint-url ${api_endpoint}/api/v2/aws/autoscaling \
    describe-auto-scaling-groups --auto-scaling-group-names ${asg_name} \
    --query 'AutoScalingGroups[0].AutoScalingGroupName' \
    --output text")

if [ x"${reported_asg_name}" == x"${asg_name}" ]
then
  echo "master_auto_scaling_group_exists true"
else
  echo "master_auto_scaling_group_exists false"
fi
