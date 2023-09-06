#!/bin/bash

# info logs the given argument at info log level.
info() {
    echo "[INFO] " "$@"
}

# warn logs the given argument at warn log level.
warn() {
    echo "[WARN] " "$@" >&2
}

# fatal logs the given argument at fatal log level.
fatal() {
    echo "[ERROR] " "$@" >&2
    exit 1
}

timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# The most simple "leader election" you've ever seen in your life
elect_leader() {
  # Fetch other running instances in ASG
  instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  instances=$(aws autoscaling describe-auto-scaling-groups --endpoint-url "$api_endpoint/api/v2/aws/autoscaling" --auto-scaling-group-name "${asg_name}" --query 'AutoScalingGroups[*].Instances[?HealthStatus==`Healthy`].InstanceId' --output text)
  sorted_instances=$(aws ec2 describe-instances --endpoint-url "$api_endpoint/api/v2/aws/ec2" --instance-ids $(echo $instances) | jq -r '.Reservations[].Instances[] | "{\"Name\": \"\(.Tags[] | select(.Key == "Name") | .["Name"] = .Value | .Name)\", \"Id\": \"\(.InstanceId)\"}"' | jq -s '.[] | { id: .Id, name: .Name, idx: (.Name | capture("(?<v>[[:digit:].]+)$").v)}' | jq -s -c 'sort_by(.idx)')
  leader_instance=$(echo $sorted_instances | jq -r '.[0].id')

  info "Current instance: $instance_id | Leader instance: $leader_instance"

  if [ "$instance_id" = "$leader_instance" ]; then
    server_type="leader"
    info "Electing as cluster leader"
  else
    info "Electing as joining server"
  fi
}

identify() {
  # Default to server
  server_type="server"
  supervisor_status=$(curl --write-out '%%{http_code}' -sk --output /dev/null https://${server_url}/ping)
  if [ "$supervisor_status" -ne 403 ]; then
    info "API server unavailable, performing simple leader election"
    elect_leader
  else
    info "API server available, identifying as server joining existing cluster"
  fi
}

cp_wait() {
  while true; do
    supervisor_status=$(curl --write-out '%%{http_code}' -sk --output /dev/null https://${server_url}/ping)
    if [ "$supervisor_status" -eq 403 ]; then
      info "Cluster is ready"

      # Let things settle down for a bit, not required
      # TODO: Remove this after some testing
      sleep 10
      break
    fi
    info "Waiting for cluster to be ready..."
    sleep 10
  done
}

local_cp_api_wait() {
  while true; do
    info "$(timestamp) Waiting for kube-apiserver..."
    if timeout 1 bash -c "true <>/dev/tcp/localhost/6443" 2>/dev/null; then
        break
    fi
    sleep 5
  done
  info "$(timestamp) Kubernetes api-server is responding on 6443 (cluster node not neccessarily ready)"
  wait $!
}

local_cp_node_wait() {
  nodereadypath='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'
  until kubectl get nodes --selector='node-role.kubernetes.io/control-plane' -o jsonpath="$nodereadypath" | grep -E "Ready=True"; do
    info "$(timestamp) Waiting for node to be ready..."
    sleep 5
  done
  info "$(timestamp) Kubernetes node is ready - cluster is up & running!"
}


{
  # All need to re-configure kubelet and set the instance provider-id (no need to restart, kubeadm will handle that)
  instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  sudo sed -i s,config.yaml,"config.yaml --cloud-provider=external --provider-id=aws:///symphony/$instance_id", $(systemctl show kubelet | grep DropInPaths | cut -d= -f 2)

  if [ "${type}" = "server" ]; then
    # Extract the internal API endpoint of the compute cluster (requires version 23.08 and above)
    api_endpoint=$(curl http://169.254.169.254/openstack/latest/meta_data.json | jq -c '.cluster_url' | cut -d\" -f2)

    # Initialize the control plane - differentiate between the leader (seeder) and other servers
    identify

    if [ $server_type = "leader" ]; then
      # Extract the exact Kubernetes version to install (get it from the already-pulled image - I know I know, it's lame...)
      kube_ver=$(sudo ctr --namespace k8s.io images list name~=public.ecr.aws/eks-distro/kubernetes/kube-apiserver:v* | tail -n 1 | cut -d' ' -f1 | cut -d':' -f2)
      sudo sed -i s,KUBE_VER,$kube_ver, /etc/kubernetes/zadara/kubeadm-config.yaml

      # Leader is initializing cluster
      info "Installing Kubernetes version $kube_ver"
      sudo kubeadm init \
        --config /etc/kubernetes/zadara/kubeadm-config.yaml \
        --upload-certs
      
      # Await for cluster to be responding before completing the setup
      local_cp_api_wait
 
      # Run post-init operations/deployments
      sudo sed -i s,API_ENDPOINT,$api_endpoint, /etc/kubernetes/zadara/cloud-config.yaml
      sudo sed -i s,API_ENDPOINT,$api_endpoint, /etc/kubernetes/zadara/values-aws-ebs-csi-driver.yaml
      export KUBECONFIG=/etc/kubernetes/admin.conf
      kubectl apply -f /etc/kubernetes/zadara/kube-flannel.yml
      kubectl apply -f /etc/kubernetes/zadara/cloud-config.yaml -n kube-system
      helm install aws-cloud-controller-manager $(ls /etc/kubernetes/zadara/aws-cloud-controller-manager-*.tgz) -f /etc/kubernetes/zadara/values-aws-cloud-controller.yaml

      # Await for cluster nodes to be ready before continuing with additional deployments & declare cluster is up & running
      local_cp_node_wait
      sudo chmod 644 /etc/kubernetes/admin.conf
      kubectl apply $(ls /etc/kubernetes/zadara/*snapshot.storage.k8s.io_*.yaml | awk ' { print " -f " $1 } ')
      kubectl apply -n kube-system -f /etc/kubernetes/zadara/rbac-snapshot-controller.yaml
      kubectl apply -n kube-system -f /etc/kubernetes/zadara/setup-snapshot-controller.yaml
      helm install aws-ebs-csi-driver $(ls /etc/kubernetes/zadara/aws-ebs-csi-driver-*.tgz) -f /etc/kubernetes/zadara/values-aws-ebs-csi-driver.yaml
      kubectl apply -f /etc/kubernetes/zadara/ebs-csi-storageclass.yaml
      kubectl apply -f /etc/kubernetes/zadara/ebs-csi-snapshotclass.yaml
    fi

    if [ $server_type = "server" ]; then 
      # Wait for cluster to exist before joining it
      cp_wait

      # Server is joining the cluster's control plane
      until sudo kubeadm join ${server_url} \
        --token ${token} \
        --discovery-token-unsafe-skip-ca-verification \
        --certificate-key ${certificate} \
        --control-plane \
        >& /dev/null; [[ $? -eq 0 ]];
        do
          warn "Kubeadm join server operation was unsuccessful - retry in 5 seconds"
          sleep 5
        done
    fi

  else
    # Workers don't need the /etc/kubernetes/zadara directory
    sudo rm -rf /etc/kubernetes/zadara

    # Wait for cluster to exist before joining it
    cp_wait

    # Worker is joining the cluster's data-plane
    until sudo kubeadm join ${server_url} \
      --token ${token} \
      --discovery-token-unsafe-skip-ca-verification \
      >& /dev/null; [[ $? -eq 0 ]];
    do 
      warn "Kubeadm join worker operation was unsuccessful - retry in 5 seconds"
      sleep 5
    done
  fi
}
