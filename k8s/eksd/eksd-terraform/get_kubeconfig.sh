#!/bin/bash

# Validate the number of arguments
if [ $# -ne 8 ]; then
    echo "Error: This script expects 8 arguments"
    echo "Usage: $0 master_hostname apiserver_private apiserver_public bastion_ip bastion_user bastion_keypair master_user master_keypair"
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

# Copy the master keypair into the bastion and fix its permissions for further usage
scp -i $bastion_keypair -o StrictHostKeyChecking=no $master_keypair $bastion_user@$bastion_ip:~/master_keypair.pem
ssh -i $bastion_keypair -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "chmod 400 ~/master_keypair.pem"

# SSH into the bastion in order to fetch the kubeconfig from the master node (can take a while, loop up to 25 minutes)
max_retry=300
for (( i=1; i<=$max_retry; i++ ))
do
    ssh -i $bastion_keypair -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "scp -i ~/master_keypair.pem -o StrictHostKeyChecking=no ${master_user}@${master_hostname}:/etc/kubernetes/admin.conf ~/kubeconfig" >& /dev/null
    if [[ $? -eq 0 ]];
    then   
        break
    fi
    echo "Couldn't obtain the kubeconfig from the master node, sleeping before retrying ($i out of $max_retry)"
    sleep 5
done

# Fetch the kubeconfig from the bastion
scp -i $bastion_keypair $bastion_user@$bastion_ip:~/kubeconfig ./kubeconfig.temp
if [[ $? -ne 0 ]];
then
    echo "Error: Cloudn't obtain the kubeconfig - check the bastion, ssh into the master node, run journalctl and look for kubeadm init errors)"
    exit 1
fi

# Replace the original API-server endpoint from the internal IP to the pulic IP
sed "s/${apiserver_private}/${apiserver_public}/g" ./kubeconfig.temp > ./kubeconfig

# Cleanup
ssh -i $bastion_keypair -o StrictHostKeyChecking=no $bastion_user@$bastion_ip "rm -f ~/kubeconfig ~/master_keypair.pem"
rm -f ./kubeconfig.temp
