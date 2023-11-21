#!/bin/bash
set -x
PATH=$PATH:/var/lib/rancher/rke2/bin/
while [ true ]
do
    KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl get nodes
    RET=$?
    if [ $RET -ne 0 ]
    then
        echo "RKE2 node is Not ready yet"
        sleep 10
    else
        echo "RKE2 node is Ready"
        exit 0
    fi
done