#!/bin/bash

# Validate the number of arguments
if [ $# -ne 9 ]; then
    echo "ERROR: This script expects 9 arguments"
    echo "Usage: $0 master_hostname apiserver_private apiserver_public bastion_ip bastion_user bastion_keypair master_user master_keypair output_kubefile_path"
    exit 1
fi

# Populate variables
master_hostname=$1
apiserver_private=$2
apiserver_public=$3
bastion_ip=$4
bastion_user=$5
bastion_keypair=$6
master_user=$7
master_keypair=$8
output_kubefile_path=$9

# Copy the master keypair into the bastion and fix its permissions for further usage
scp -i $bastion_keypair -o StrictHostKeyChecking=no $master_keypair $bastion_user@$bastion_ip:~/master_keypair.pem
ssh -i $bastion_keypair -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "chmod 400 ~/master_keypair.pem"

# SSH into the bastion in order to fetch the kubeconfig from the master node (can take a while, loop up to 25 minutes)
max_retry=300
for (( i=1; i<=$max_retry; i++ ))
do
    ssh -i $bastion_keypair -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "ssh -i ~/master_keypair.pem -o StrictHostKeyChecking=no ${master_user}@${master_hostname} sudo cat /etc/kubernetes/zadara/kubeconfig > /tmp/kubeconfig" >& /dev/null
    scp -i $bastion_keypair -o StrictHostKeyChecking=no $bastion_user@$bastion_ip:/tmp/kubeconfig ./kubeconfig.temp
    grep apiVersion ./kubeconfig.temp >& /dev/null
    if [[ $? -eq 0 ]];
    then
        ssh -i $bastion_keypair -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "ssh -i ~/master_keypair.pem -o StrictHostKeyChecking=no ${master_user}@${master_hostname} sudo rm /tmp/kubeconfig" >& /dev/null
        break
    fi
    echo "`date`: Couldn't obtain the kubeconfig from the master node, sleeping before retrying ($i out of $max_retry)"
    sleep 5
done

# Make sure we have a non-empty file
grep apiVersion ./kubeconfig.temp >& /dev/null
if [[ $? -ne 0 ]];
then
    echo "ERROR: failed to obtain kubeconfig - check the bastion, ssh into the oldest master node and search for errors in /var/log/cloud-init-output.log"
    exit 1
fi
# Remove it from the bastion
ssh -i $bastion_keypair -o StrictHostKeyChecking=no $bastion_user@$bastion_ip rm /tmp/kubeconfig >& /dev/null

# Replace the original API-server endpoint from the internal IP to the public IP (only if public IP is really provided)
if [[ $apiserver_public != "None" ]];
then
    sed "s/${apiserver_private}/${apiserver_public}/g" ./kubeconfig.temp > "${output_kubefile_path}"
else
    cp ./kubeconfig.temp "${output_kubefile_path}"
fi

# Cleanup
ssh -i $bastion_keypair -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "rm -f ~/kubeconfig ~/master_keypair.pem"
rm -f ./kubeconfig.temp
