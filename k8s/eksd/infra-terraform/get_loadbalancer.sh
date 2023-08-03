#!/bin/bash

set -e

# Validate the number of arguments
if [ $# -ne 7 ]; then
    echo "Error: This script expects 7 arguments"
    echo "Usage: $0 api_endpoint bastion_ip loadbalancer_dns access_key secret_key bastion_user bastion_key"
    exit 1
fi

# Populate variables
api_endpoint=$1
bastion_ip=$2
loadbalancer_dns=$3
access_key=$4
secret_key=$5
bastion_user=$6
bastion_key=$7

# Get the private IP based on the private DNS of the LoadBalancer
private_ip=$(ssh -i $bastion_key -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "getent hosts $loadbalancer_dns | awk '{ print \$1 }'")

# Install the AWS CLI on the bastion VM
ssh -T -i $bastion_key -o StrictHostKeyChecking=no $bastion_user@$bastion_ip<< EOF
sudo yum install -y -q unzip || sudo apt-get install -y -q unzip
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install
EOF

# Invoke AWS CLI to get the public IP of the LoadBalancer
public_ip=$(ssh -i $bastion_key -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "\
    AWS_ACCESS_KEY_ID=$access_key AWS_SECRET_ACCESS_KEY=$secret_key \
    aws ec2 describe-network-interfaces \
    --endpoint-url https://$api_endpoint/api/v2/aws/ec2 \
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
