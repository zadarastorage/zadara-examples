#!/bin/sh

export TYPE="${type}"

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

append_config() {
  echo "$1" >> "/etc/rancher/rke2/config.yaml"
}

# The most simple "leader election" you've ever seen in your life
elect_leader() {
  # Fetch other running instances in ASG
  instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  instances=$(aws autoscaling describe-auto-scaling-groups --endpoint-url "https://${api_url}/api/v2/aws/autoscaling" --auto-scaling-group-name "${asg_name}" --query 'AutoScalingGroups[*].Instances[?HealthStatus==`Healthy`].InstanceId' --output text)
  sorted_instances=$(aws ec2 describe-instances --endpoint-url "https://${api_url}/api/v2/aws/ec2" --instance-ids $(echo -e $instances) | jq -r '.Reservations[].Instances[] | "{\"Name\": \"\(.Tags[] | select(.Key == "Name") | .["Name"] = .Value | .Name)\", \"Id\": \"\(.InstanceId)\"}"' | jq -s '.[] | { id: .Id, name: .Name, idx: (.Name | capture("(?<v>[[:digit:].]+)$").v)}' | jq -s -c 'sort_by(.idx)')
  leader_instance=$(echo $sorted_instances | jq -r '.[0].id')

  info "Current instance: $instance_id | Leader instance: $leader_instance"

  if [ "$instance_id" = "$leader_instance" ]; then
    SERVER_TYPE="leader"
    info "Electing as cluster leader"
  else
    info "Electing as joining server"
  fi
}

identify() {
  # Default to server
  SERVER_TYPE="server"

  supervisor_status=$(curl --write-out '%%{http_code}' -sk --output /dev/null ${server_url}/ping)

  if [ "$supervisor_status" -ne 200 ]; then
    info "API server unavailable, performing simple leader election"
    elect_leader
  else
    info "API server available, identifying as server joining existing cluster"
  fi
}

cp_wait() {
  while true; do
    supervisor_status=$(curl --write-out '%%{http_code}' -sk --output /dev/null ${server_url}/ping)
    if [ "$supervisor_status" -eq 200 ]; then
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
  export PATH=$PATH:/var/lib/rancher/rke2/bin
  export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

  while true; do
    info "$(timestamp) Waiting for kube-apiserver..."
    if timeout 1 bash -c "true <>/dev/tcp/localhost/6443" 2>/dev/null; then
        break
    fi
    sleep 5
  done

  wait $!

  nodereadypath='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'
  until kubectl get nodes --selector='node-role.kubernetes.io/master' -o jsonpath="$nodereadypath" | grep -E "Ready=True"; do
    info "$(timestamp) Waiting for servers to be ready..."
    sleep 5
  done

  info "$(timestamp) all kube-system deployments are ready!"
}

{
  if [ $TYPE = "server" ]; then
    # Initialize server
    identify

    if [ $SERVER_TYPE = "server" ]; then     # additional server joining an existing cluster
      append_config 'server: ${server_url}'
      # Wait for cluster to exist, then init another server
      cp_wait
    fi

    instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    cat <<EOF >> "/etc/rancher/rke2/config.yaml"
kubelet-arg:
  - "provider-id=aws:///symphony/$instance_id"
EOF
    systemctl enable rke2-server
    systemctl daemon-reload
    systemctl start rke2-server

    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    export PATH=$PATH:/var/lib/rancher/rke2/bin

    if [ $SERVER_TYPE = "leader" ]; then
      # For servers, wait for apiserver to be ready before continuing so that `post_userdata` can operate on the cluster
      local_cp_api_wait
    fi

  else
    append_config 'server: ${server_url}'

    instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    cat <<EOF >> "/etc/rancher/rke2/config.yaml"
kubelet-arg:
  - "provider-id=aws:///symphony/$instance_id"
EOF
    # Default to agent
    systemctl enable rke2-agent
    systemctl daemon-reload
    systemctl start rke2-agent
  fi
}
