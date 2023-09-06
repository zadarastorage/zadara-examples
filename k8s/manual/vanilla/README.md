
Vanilla/EKS-D Kubernetes - manual deployment procedure
======================================================

The below procedure demostrate how Zadara customers can deploy either vanilla or EKS-D Kubernetes on top of the Zadara cloud - please note this an example rather than a production-grade solution, specifically this is **not** an automated solution (although it can be automated in various ways). 

Known limitations
-----------------
* zCompute minimal version is **22.09.04** (previous versions don't support the EC2 API required by the AWS Cloud Provider for Kubernetes as an external CCM)
* For zCompute version 22.09.04, the maximal AWS CCM release to support NLB is `v1.25.3` (later zCompute versions can use any AWS CCM release)
* EBS CSI requires modifying the [udev service](https://manpages.ubuntu.com/manpages/jammy/man7/udev.7.html), allowing API calls to be made upon new volume attachment
* EBS CSI snapshotting is not fully operational (will create more snapshots than needed and will not delete them upon snapshot removal)


zCompute prerequisites
----------------------
* Infrastructure considerations
    * Pre-configured VPC with a public subnet (using routing table and Internet-Gateway) is the minimal requirement, private subnet is advised for all internal components - you can use the VPC wizard to create the neccessary network topology
    * Pre-configured AWS Role with the [relevant policies](https://cloud-provider-aws.sigs.k8s.io/prerequisites/#iam-policies "https://cloud-provider-aws.sigs.k8s.io/prerequisites/#iam-policies") (EC2, ASG, ELB, etc.) - you can just use the managed policies of `AmazonEC2FullAccess`, `ElasticLoadBalancingFullAccess` & `AutoScalingFullAccess` and add them to a new Role with a simple name (without spaces) for clarity
    * Pre-configured AWS Instance Profile with the previous Role added to - assuming you have an AWS CLI [installed](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) & configured you can run the below to create it: 
      ```shell
      aws iam --endpoint-url https://{zcompute-api}/api/v2/aws/iam/ create-instance-profile --instance-profile-name {name}
      aws iam --endpoint-url https://{zcompute-api}/api/v2/aws/iam/ add-role-to-instance-profile --instance-profile-name {name} --role-name {role-name}
      ```

* VM considerations
    * The Operating System should be Linux-based (below instructions assume Ubuntu 22.04) - make sure to download the relevant OS image from the Marketplace
    * Subnet can be private or public depending on the desired network topology (for private subnets, create a bastion on the public subnet and use it to ssh into the private one)
    * Make sure to update the relevant Security Group and allow relevant communication rules - specifically ports 22 (for SSH) and 6443 (for Kubernetes API server)
    * The minimal recommendation for instance type is z4.large
    * The minimal recommendation for root disk size is 25GB
    * Once the instance is created, get its AWS ID and associate it with the aforementioned Instance Profile - you can use the below AWS CLI commands: 
      ```shell
      # This will get you the Instance Profile's ARN based on its name:
      aws iam --endpoint-url https://{zcompute-api}/api/v2/aws/iam/ get-instance-profile --instance-profile-name {name} --query 'InstanceProfile.Arn'
      
      # This will associate the Instance Profile with the VM based on the VM's instance ID:
      aws ec2 --endpoint-url https://{zcompute-api}/api/v2/aws/ec2/ associate-iam-instance-profile --iam-instance-profile Arn={ARN},Name={name} --instance-id {instance-id}
      ```
        

Kubernetes prerequisites
------------------------

### Linux settings

*   For Ubuntu 22.04 LTS, due to a new cloud-init version the [hostname](https://cloudinit.readthedocs.io/en/latest/reference/modules.html#set-hostname "https://cloudinit.readthedocs.io/en/latest/reference/modules.html#set-hostname") is set without the FQDN, so in oder to prevent DNS issues down the road you should change the hostname to reflect the zCompute FQDN (or bring your own cloud-init script):
    
    ```shell
    sudo hostnamectl set-hostname "${HOSTNAME}.symphony.local"
    ```

### Container runtime

*   Run the below container runtime [prerequisites](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#forwarding-ipv4-and-letting-iptables-see-bridged-traffic "https://kubernetes.io/docs/setup/production-environment/container-runtimes/#forwarding-ipv4-and-letting-iptables-see-bridged-traffic"):
    
    ```shell
    sudo cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF

    sudo modprobe overlay
    sudo modprobe br_netfilter

    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF

    sudo sysctl --system
    ```
    
*   Install a runtime - the EKS-D docs refer to Docker but we need [containerd](https://containerd.io "https://containerd.io") or another CRI-compatible runtime for modern (1.24 and above) k8s versions:
    ```shell
    # Add the docker repo
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo   "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
        
    # Install containerd.io
    sudo apt-get install -y containerd.io

    # Enable the CRI plugin (disabled by default)
    sudo sed -i '/disabled_plugins = \["cri"\]/d' /etc/containerd/config.toml

    # Set runc to use version 2 with the systemd plugin
    sudo tee -a /etc/containerd/config.toml > /dev/null <<EOT
    version = 2
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
      runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        SystemdCgroup = true
    EOT

    # Enable & (re)start the service
    sudo systemctl enable containerd
    sudo systemctl restart containerd
    ```
    

### Kubernetes binaries

*   Install the `kubelet`, `kubeadm` & `kubectl` packages:
    
    ```shell
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    ```
    
*   Note: In releases older than Debian 12 and Ubuntu 22.04, `/etc/apt/keyrings` does not exist by default. You can create this directory if you need to, making it world-readable but writeable only by admins.
        
*   For EKS-D, override the original binaries with the ones compatible to your desired EKS-D [release](https://github.com/aws/eks-distro#releases "https://github.com/aws/eks-distro#releases") (check the relevant URI in the manifest), for example for deploying EKS-D 1.27 release #8 which is currently the latest and based on Kubernetes 1.27.3:
    ```shell
    cd /usr/bin
    sudo rm kubelet kubeadm kubectl
    sudo wget https://distro.eks.amazonaws.com/kubernetes-1-27/releases/8/artifacts/kubernetes/v1.27.3/bin/linux/amd64/kubelet
    sudo wget https://distro.eks.amazonaws.com/kubernetes-1-27/releases/8/artifacts/kubernetes/v1.27.3/bin/linux/amd64/kubeadm
    sudo wget https://distro.eks.amazonaws.com/kubernetes-1-27/releases/8/artifacts/kubernetes/v1.27.3/bin/linux/amd64/kubectl
    sudo chmod +x kubeadm kubectl kubelet
    cd ~
    ```
        
*   Enable the kubelet service:  
    `sudo systemctl enable kubelet`

Control-plane installation
--------------------------

### kubeadm

*   Note that kubeadm search for images based on [naming conventions](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#custom-images "https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#custom-images") which in some cases are not honored by EKS-D and we need to align them one way or another:
    
    *   Run `sudo kubeadm config images pull` (or `list`) to make sure all images are available - for EKS-D you'll need to prodive the AWS image repository & EKS-D release, for example:  
        ```shell
        sudo kubeadm config images pull --image-repository public.ecr.aws/eks-distro/kubernetes --kubernetes-version v1.27.3-eks-1-27-8
        ```
        
    *   If you try to pull the EKS-D images you will find some are “missing” due to naming conventions - specifically we need to make sure etcd & coredns will be “corrected” per the EKS-D manifest. We can workaround the issue in 2 possible ways:
        
        *   Pre-pull and re-tag the relevant images locally (as suggested on the [EKS-D docs](https://distro.eks.amazonaws.com/users/install/kubeadm-onsite/#set-up-a-control-plane-node "https://distro.eks.amazonaws.com/users/install/kubeadm-onsite/#set-up-a-control-plane-node") in step 3 and [other examples](https://aws.amazon.com/blogs/storage/running-kubernetes-cluster-with-amazon-eks-distro-across-aws-snowball-edge/ "https://aws.amazon.com/blogs/storage/running-kubernetes-cluster-with-amazon-eks-distro-across-aws-snowball-edge/")) - although the documented docker-based approach requires docker as well as AWS [authentication](https://docs.aws.amazon.com/AmazonECR/latest/public/getting-started-cli.html#cli-authenticate-registry "https://docs.aws.amazon.com/AmazonECR/latest/public/getting-started-cli.html#cli-authenticate-registry"))
            
        *   Use a detailed kubeadm [configuration file](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/ "https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/") and state the relevant [ClusterConfiguration](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-ClusterConfiguration "https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-ClusterConfiguration") resources to list the repository/name/tag accordingly, set the cluster name, etc.
            
    *   We suggest following the re-tag approach but instead of docker use `ctr` (the containerd CLI utility) with the `--namespace k8s.io` attribute to pull & re-tag the relevant images based on the original EKS-D manifest (you can also use `crictl` for the pull but it can't re-tag):
        ```shell
        sudo ctr --namespace k8s.io images pull public.ecr.aws/eks-distro/coredns/coredns:v1.10.1-eks-1-27-8
        sudo ctr --namespace k8s.io images tag public.ecr.aws/eks-distro/coredns/coredns:v1.10.1-eks-1-27-8 public.ecr.aws/eks-distro/kubernetes/coredns:v1.10.1

        sudo ctr --namespace k8s.io images pull public.ecr.aws/eks-distro/etcd-io/etcd:v3.5.7-eks-1-27-8
        sudo ctr --namespace k8s.io images tag public.ecr.aws/eks-distro/etcd-io/etcd:v3.5.7-eks-1-27-8 public.ecr.aws/eks-distro/kubernetes/etcd:3.5.7-0
        ```
        
*   Initialize kubeadm
    
    *   Run the kubeadm initialization with the targeted internal pods network CIDR (here we use 10.244.0.0/16) and again the optional EKS-D parameters if relevant:  
        `sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --image-repository public.ecr.aws/eks-distro/kubernetes --kubernetes-version v1.27.3-eks-1-27-8`
        
    * For public-facing Kubernetes clusters, assuming your control plane VM has an additional public IP, you may want to add the `--apiserver-cert-extra-sans` flag with the relevant IP address so later on you can refer to that IP as an alternative server address which will be respected by the server certificate. 

    *   If something goes wrong you might need to run `kubeadm reset` before you can init again…
        
    *   A successful output should produce an output ending with the `kubeadm join` command with the dedicated token, to be used by any future worker nodes.
        
*   Follow the kubectl configuration instructions and make sure it works, for example:
    ```shell
    cd ~
    mkdir ~/.kube
    sudo cp /etc/kubernetes/admin.conf ~/.kube/config
    sudo chown ubuntu:ubuntu ~/.kube/config
    kubectl get nodes
    ```
    
*   Note that by default, kubeadm name the cluster as “kubernetes” and you may change that either with a [ClusterConfiguration](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-ClusterConfiguration "https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-ClusterConfiguration") setting (using a configuration file before the init phase) or manually after the control plane is up, by editing the kubeadm-config ConfigMap (`kubectl edit configmaps kubeadm-config -n kube-system`) and changing the `clusterName` attribute.


### CNI

*   Deploy either Flannel or Calico:
    
    *   For [Flannel](https://github.com/flannel-io/flannel "https://github.com/flannel-io/flannel") the CIDR is the default so no changes required: \
    `kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml`
    *   For [Calico](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart "https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart") you’ll need to specify the CIDR in the custom-resources.yaml:
        ```shell
        kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
        curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml -O
        sed -i 's,192.168.0.0/16,10.244.0.1/24,g' custom-resources.yaml
        kubectl create -f custom-resources.yaml
        ```
        
*   In case something went wrong with the CNI, you can perform the following:
    *   Reset the cluster before re-initializing it   
        Remove Kubernetes \
        `sudo kubeadm reset`  
        Remove the CNI network directory \
        `rm -rf /etc/cni/net.d`  
    *   Delete the CNI network interface  
        Check which interfaces were created \
        `ip -4 addr show`  
        Delete the relevant one/s for example \
        `ip link delete cni0`  
    *   Restart containerd \
        `sudo systemctl restart containerd`
           
*   Once the CNI pod/s are running   
    * Make sure the master node is now ready: \
      `kubectl get nodes`     
    * Make sure coredns pods are running as well:  \
      `kubectl get pods -A -l k8s-app=kube-dns -o wide`
        
*   If you wish to run actual workloads on the master node, remember to remove the taint from the master node:  
    `kubectl taint nodes --all node-role.kubernetes.io/control-plane-`
    

### AWS cloud provider for Kubernetes

*   Follow the instructions for [cloud-controller-manager](https://kubernetes.io/docs/tasks/administer-cluster/running-cloud-controller/#running-cloud-controller-manager "https://kubernetes.io/docs/tasks/administer-cluster/running-cloud-controller/#running-cloud-controller-manager") (CCM) as well as the [AWS cloud provider documentation](https://github.com/kubernetes/cloud-provider-aws/blob/master/docs/getting_started.md#when-downtime-is-acceptable "https://github.com/kubernetes/cloud-provider-aws/blob/master/docs/getting_started.md#when-downtime-is-acceptable") regarding the prerequisites:
    
    *   Switch to external cloud provider:
        ```shell
        # Stop the kube-controller-manager static pod by moving its config away
        sudo mv /etc/kubernetes/manifests/kube-controller-manager.yaml /etc/kubernetes/

        # Edit the unused file and add the --cloud-provider=external flag
        sudo sed -i /'- kube-controller-manager'/a'\ \ \ \ - --cloud-provider=external' /etc/kubernetes/kube-controller-manager.yaml

        # Move the file back in order for kube-controller-manager to re-launch with the flag
        sudo mv /etc/kubernetes/kube-controller-manager.yaml /etc/kubernetes/manifests/

        # Dynamically edit the kube-apiserver static pod to run with the same flag by edit its yaml
        sudo sed -i /'- kube-apiserver'/a'\ \ \ \ - --cloud-provider=external' /etc/kubernetes/manifests/kube-apiserver.yaml

        # Get the instance id from the metadata service
        export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

        # Change the kubelet service configuration to use the new settings
        sudo sed -i s,config.yaml,"config.yaml --cloud-provider=external --provider-id=aws:///symphony/$INSTANCE_ID", $(systemctl show kubelet | grep DropInPaths | cut -d= -f 2)

        # Restart kubelet with the new config
        sudo systemctl daemon-reload
        sudo systemctl restart kubelet
        ```
        
    *   Add the required tag `kubernetes.io/cluster/{kubernetes-name}=owned` (the default cluster name is “kubernetes” as mentioned before, and it is advised to rename as it may become an issue with more than a single cluster per zCompute account) to the relevant cloud resources via the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html") or zCompute GUI:  
        ```shell
        aws --region us-east-1 --endpoint-url=https://{zcompute-api}/api/v2/ec2/ ec2 create-tags --resources {resource-id} --tags Key=kubernetes.io/cluster/{kubernetes-name},Value=owned
        ```
        
        *   VM instance
        *   VPC subnet (additional tags [may be required](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html#network-requirements-subnets "https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html#network-requirements-subnets") for Load Balancer resources) 

*   Install [AWS Cloud Provider for Kubernetes](https://github.com/kubernetes/cloud-provider-aws/tree/master/charts/aws-cloud-controller-manager#configuration "https://github.com/kubernetes/cloud-provider-aws/tree/master/charts/aws-cloud-controller-manager#configuration")
    
    *   Create a new ConfigMap called cloud-config containing your zCompute URL:
        ```shell
        cat <<EOF | tee ~/cloud-config.yaml
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: cloud-config
        data:
          cloud.conf: |
            [Global]
             Zone=us-east-1-az1
            [ServiceOverride "ec2"]
             Service=ec2
             Region=us-east-1
             URL=https://{zCompute-URL}/api/v2/aws/ec2
             SigningRegion=us-east-1
            [ServiceOverride "elasticloadbalancing"]
             Service=elasticloadbalancing
             Region=us-east-1
             URL=https://{zCompute-URL}/api/v2/aws/elbv2
             SigningRegion=us-east-1
        EOF
        ```
        
    *   Make sure to edit the file and update the zCompute URL before applying it:  
        `kubectl apply -f ~/cloud-config.yaml -n kube-system`
        
    *   If you want to use the [Helm deployment](https://github.com/kubernetes/cloud-provider-aws/blob/master/docs/getting_started.md#when-downtime-is-acceptable "https://github.com/kubernetes/cloud-provider-aws/blob/master/docs/getting_started.md#when-downtime-is-acceptable") (otherwise you’ll need to download the [manual deployment](https://github.com/kubernetes/cloud-provider-aws/blob/master/docs/getting_started.md#when-downtime-is-acceptable "https://github.com/kubernetes/cloud-provider-aws/blob/master/docs/getting_started.md#when-downtime-is-acceptable") GitHub repository), make sure Helm is installed - if not, get the latest [release binary](https://github.com/helm/helm/releases "https://github.com/helm/helm/releases") and install it before installing the chart:
        ```shell
        # Get & install Helm
        wget https://get.helm.sh/helm-v3.11.2-linux-amd64.tar.gz
        tar -zxvf helm-v3.11.2-linux-amd64.tar.gz
        sudo mv linux-amd64/helm /usr/local/bin/helm

        # Add the AWS cloud provider repo
        helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
        helm repo update

        # Prepare the values file
        cat <<EOF | tee ~/values-aws-cloud-controller.yaml
        args:
        - --v=2
        - --cloud-provider=aws
        - --cloud-config=config/cloud.conf
        - --allocate-node-cidrs=false
        - --cluster-cidr={pod network CIDR, for example 10.244.0.1/24}
        - --cluster-name={kubernetes-name, for example kubernetes}
        - --configure-cloud-routes=false
        image:
          tag: {relevant image version for your zCompute/EKS-D, for example v1.25.3}
        cloudConfigPath: config/cloud.conf
        extraVolumes:
        - name: cloud-config
          configMap:
            name: cloud-config
        extraVolumeMounts:
        - name: cloud-config
          mountPath: config
        EOF
        ```
        
        Make sure to update the values file before installing the chart:  
        `helm upgrade --install aws-cloud-controller-manager aws-cloud-controller-manager/aws-cloud-controller-manager -f ~/values-aws-cloud-controller.yaml`
        
    *   See that the aws-cloud-controller-manager pod is running without errors in its logs
        
        *   Specifically you might want to check the k8s node has a “providerID” value:  
            `kubectl get nodes -o=jsonpath='{.items[0].spec.providerID}'`  
            The value should be the instance id and if you didn’t add it during the kubelet initialization you can add it ad-hoc via:  
            `kubectl patch node <node_name> -p '{"spec":{"providerID":"aws:///symphony/<instance_id>"}}'`
            
*   With the controller in place, you will be able to enjoy the following functionalities
    
    *   Node information & lifecycle management
        *   Worker nodes will get cloud-oriented labels such as instance type, etc.
        *   All nodes will reflect cloud instances status changes
            
    *   LoadBalancer services
        *   Check out the relevant annotations in the service controller [documentation](https://github.com/kubernetes/cloud-provider-aws/blob/21acaa9cb3e801cf20ee33094f7765eeedd155c7/docs/service_controller.md "https://github.com/kubernetes/cloud-provider-aws/blob/21acaa9cb3e801cf20ee33094f7765eeedd155c7/docs/service_controller.md") and note that additional [subnet-level tagging](https://repost.aws/knowledge-center/eks-vpc-subnet-discovery "https://repost.aws/knowledge-center/eks-vpc-subnet-discovery") may be required
            
        *   Note the minimal required annotation is (the controller only support NLB): \
            `service.beta.kubernetes.io/aws-load-balancer-type: nlb`
        *   Note that the default NLB is internal-facing, so for external-facing NLB use the below: \
            `service.beta.kubernetes.io/aws-load-balancer-internal: "false"`
            
        *   For ALB support (using the Ingress resource) you can use the AWS [Load Balancer Controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller "https://github.com/kubernetes-sigs/aws-load-balancer-controller") as an additional standalone deployment which can handle both types of Load Balancers.
            
            *   If you wish to install it through Helm, remember to override the below values:
                ```yaml
                clusterName:  # cluster name (terraform's "environment" variable from step #3)
                vpcId: # cluster's vpc id
                awsApiEndpoints: "ec2=https://<cluster_hostname>/api/v2/aws/ec2,elasticloadbalancing=https://<cluster_hostname>/api/v2/aws/elbv2,acm=https://<cluster_hostname>/api/v2/aws/acm,sts=https://<cluster_hostname>/api/v2/aws/sts"
                enableShield: false
                enableWaf: false
                enableWafv2: false
                region: eu-west-1
                ```
                
            *   For NLB - use the LoadBalancer service per the [documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/annotations "https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/annotations") and note that as a [known limitation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/nlb/#security-group "https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/nlb/#security-group"), the controller wouldn't create the relevant security group to the NLB - rather, it will add the relevant rules to the worker node's security group and you can attach this (or another) security group to the NLB via the zCompute GUI, AWS CLI or Symp
                ```yaml
                service:
                  annotations:
                    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: instance
                    service.beta.kubernetes.io/aws-load-balancer-type: external
                    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
                ```
                
            *   For ALB - use the Ingress resource per the [documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations "https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations")
                
                *   Set the `ingressClassName` attribute per the controller class name (default is `alb`)
                    
                *   By default all Ingress resources are [internal-facing](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations/#scheme "https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations/#scheme") - if you want your ALB to get a public IP you will have to set the `alb.ingress.kubernetes.io/scheme` annotation to `internet-facing` (default value is `internal`)
                    

HA-setup
--------

If you wish to create an HA-based cluster instead of a single control-plane node, make sure to follow the [prerequisites](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/ "https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/") **before** initializing the cluster:

*   Create the first (seeder) control plane VM and follow the usual instructions until the cluster initialization step (stop before running the `kubeadm init` command).
    
*   Create an NLB (TCP-based) Load Balancer on zCompute
    
    *   Make sure to place it on the same VPC, and for Public-facing clusters it would reside on the public subnet and get a public IP
        
    *   Create a TCP-based listener for the LB and use the default port 6443 (or change it accordingly throughout the following instructions)
        
    *   Forward all requests to a TCP-based target group which will use the same port for health checks
        
    *   Add all relevant control-plane VMs as targets (you can start with the initial seeder VM and later add the rest)
        
*   Initialize the cluster using the LB private IP as the control-plane endpoint, add the public IP as an alternative SAN (if relevant, only for public-facing clusters) and upload the cluster certificates as a 2-hours TTL secret - use the EKS-D parameters if relevant:  
    `sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint <LB-private-ip>:6443 --apiserver-cert-extra-sans <LB-public-ip> --upload-certs --image-repository public.ecr.aws/eks-distro/kubernetes --kubernetes-version v1.27.3-eks-1-27-8`
    
*   Continue with the cluster deployment as usual - note the kubeconfig file will reflect the LB private IP as the api server URL and you may want to change it to the public IP (so you wouldn’t need to proxy into it for remote access)
    
*   Join the other control-plane VMs within 2 hours to the existing seeder (if you need longer time, you can always create a new certificate with `kubeadm certs certificate-key` on the seeder side and use the output for the new VM side)
    
    *   **On the seeder control-plane VM** run:  
        `sudo kubeadm token create --print-join-command`
        
    *   **On the new control-plane VMs** run the output of that command with `sudo` and also add `--control-plane` to note this is a control-plane node and not a data-plane node
        
*   Alternatively in order to enable an automation-friendly approach, you can use a predefined certificate as well as a token (format is `XXXXXX.XXXXXXXXXXXXXXXX`) to last forever (with `--ttl 0`) on all of the VMs. You would still need to run the commands on both sides, but if you're willing to [skip the control-plane's CA public key validation](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/#token-based-discovery-without-ca-pinning "https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/#token-based-discovery-without-ca-pinning"), you won’t need to exchange values between VMs:
    
    *   **On the seeder control-plane VM** run:  
        `sudo kubeadm init phase upload-certs --upload-certs --certificate-key 12345678901234567890123456789012`  
        `sudo kubeadm token create --ttl 0 123456.1234567890123456`
        
    *   **On the new control-plane VMs** run:  
        `sudo kubeadm join <LB-public-ip>:6443 --token 123456.1234567890123456 --discovery-token-unsafe-skip-ca-verification --control-plane --certificate-key 12345678901234567890123456789012`
        
    *   Note that the uploaded certificate is only stored for 2 hours as a secret on the cluster (check it with `kubectl get secrets -n kube-system kubeadm-certs`) and will require a constant refresh via crontab or equivalent in order to allow continuous joining, for example:  
        `(sudo crontab -l && echo "0 */1 * * * sudo kubeadm init phase upload-certs --upload-certs --certificate-key 12345678901234567890123456789012") | sudo crontab -`
        
    *   Note that in such use-case, the order of execution is irrelevant - the new VMs will try to authenticate with the seeder (through the API Server cluster-info ConfigMap and the certificate secret) every 5 seconds and up to [5 minutes](https://github.com/kubernetes/kubernetes/blob/master/cmd/kubeadm/app/constants/constants.go#L212 "https://github.com/kubernetes/kubernetes/blob/master/cmd/kubeadm/app/constants/constants.go#L212"). There’s no built-in mechanism to extend this timeout so if necessary you could use a script to check the exit status of the join command, for example:
        ```shell
        cat <<EOF | tee ~/connect.sh
        #!/bin/bash

        until kubeadm join <LB-public-ip>:6443 --token 123456.1234567890123456 --discovery-token-unsafe-skip-ca-verification --control-plane --certificate-key <key>  >& /dev/null; [[ $? -eq 0 ]];
        do
          echo "Result unsuccessful"
          sleep 5
        done
        ```
        

Data-plane installation
-----------------------

If you wish to add data-plane (worker) nodes to your Kubernetes cluster:

*   Add additional instance for the worker node (same considerations as the control-plane VM)
    
*   Follow the same steps mentioned in [Kubernetes prerequisites](https://zadara.atlassian.net/wiki/spaces/~6231a47173c8ec00699d1181/pages/2086797649/EKS-D+Manual+deployment+POC#Kubernetes-prerequisites "https://zadara.atlassian.net/wiki/spaces/~6231a47173c8ec00699d1181/pages/2086797649/EKS-D+Manual+deployment+POC#Kubernetes-prerequisites")
    
*   Switch kubelet to external cloud provider and refer the node’s provider-id to the instance id:
    ```shell
    # Get the instance id from the metadata service
    export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

    # Change the kubelet service configuration
    sudo sed -i s,config.yaml,"config.yaml --cloud-provider=external --provider-id=aws:///symphony/$INSTANCE_ID", $(systemctl show kubelet | grep DropInPaths | cut -d= -f 2)

    # Restart kubelet with the new config
    sudo systemctl daemon-reload
    sudo systemctl restart kubelet
    ```
    
*   Join the worker to the existing Kubernetes cluster
    
    *   **On the control-plane VM** run:  
        `sudo kubeadm token create --print-join-command`
        
    *   **On the data-plane (worker) VM** run the output of that command with `sudo`
        
*   Alternatively in order to enable an automation-friendly approach, you can use a predefined token (format is `XXXXXX.XXXXXXXXXXXXXXXX`) to last forever (with `--ttl 0`) on both master & workers. You would still need to run the commands on both sides, but if you're willing to [skip the control-plane's CA public key validation](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/#token-based-discovery-without-ca-pinning "https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/#token-based-discovery-without-ca-pinning"), you won’t need to exchange values between VMs:
    
    *   **On the control-plane VM** run:  
        `sudo kubeadm token create --ttl 0 123456.1234567890123456`
        
    *   **On the data-plane (worker) VM** run:  
        `sudo kubeadm join <control-plane-endpoint>:6443 --token 123456.1234567890123456 --discovery-token-unsafe-skip-ca-verification`
        
    *   Note that in such use-case, the order of execution is irrelevant - the worker will try to authenticate with the control-plane (through the API Server cluster-info ConfigMap) every 5 seconds and up to [5 minutes](https://github.com/kubernetes/kubernetes/blob/master/cmd/kubeadm/app/constants/constants.go#L212 "https://github.com/kubernetes/kubernetes/blob/master/cmd/kubeadm/app/constants/constants.go#L212"). There’s no built-in mechanism to extend this timeout so if necessary we should use a script to check the exit status of the join command, for example:
        ```shell
        cat <<EOF | tee ~/connect.sh
        #!/bin/bash

        until kubeadm join 10.0.0.22:6443 --token 123457.1234567890123457 --discovery-token-unsafe-skip-ca-verification  >& /dev/null; [[ $? -eq 0 ]];
        do
          echo "Result unsuccessful"
          sleep 5
        done
        EOF
        ```
        

EBS CSI
-------

*   zCompute prerequisite - you must install a fix for mounted device names on all worker nodes in order to allow the EBS CSI to mount them
    
    *   Set [the script](https://raw.githubusercontent.com/Neokarm/neokarm-examples/mc-lb/k8s/extra/disk-mapper/symphony_disk_mapper.template.py "https://raw.githubusercontent.com/Neokarm/neokarm-examples/mc-lb/k8s/extra/disk-mapper/symphony_disk_mapper.template.py"):
        
        *   Download the script into a new file:  
            `sudo wget https://raw.githubusercontent.com/Neokarm/neokarm-examples/mc-lb/k8s/extra/disk-mapper/symphony_disk_mapper.template.py -O /usr/bin/symphony_disk_mapper.py`
            
        *   Make the following hardcoded changes to the script:
            ```shell
            # Set the python executable (no path under the udev service execution)
            sudo sed -i s,'/usr/bin/env python3','/usr/bin/python3', /usr/bin/symphony_disk_mapper.py

            # Update the default bundle for Ubuntu
            sudo sed -i s,'/etc/pki/tls/certs/ca-bundle.crt','/etc/ssl/certs/ca-certificates.crt', /usr/bin/symphony_disk_mapper.py
            ```
            
        *   Set the zCompute hostname inside the script  
            `sudo sed -i s,'${ symphony_ec2_endpoint }',https://{zCompute_hostname}/api/v2/aws/ec2, /usr/bin/symphony_disk_mapper.py`
            
        *   Make sure the script is runnable  
            `sudo chmod +x /usr/bin/symphony_disk_mapper.py`
            
*   Try to run the script just to make sure python is working - if not, make sure python is installed on the server together with all relevant packages:
    ```shell
    sudo apt install -y python3-pip
    sudo pip3 install boto3 
    sudo pip3 install retrying 
    sudo pip3 install requests 
    sudo pip3 install pyudev
    ```
    
*   Create another new file pointing to this script:
    ```shell
    cat <<EOF | sudo tee /etc/udev/rules.d/symphony_disk_mapper.rules
    KERNEL=="vd*[!0-9]", PROGRAM="/usr/bin/symphony_disk_mapper.py %k", SYMLINK+="%c"
    EOF
    ```
    
*   Remove the snap auto-import rule for block devices automated mounting:  
    `sudo rm /lib/udev/rules.d/66-snapd-autoimport.rules`
    
*   Remove the udev service networking limitations  
    `sudo sed -i '/IPAddressDeny=any/d' /lib/systemd/system/systemd-udevd.service`
    
*   Reload the udev service & rules
    ```shell
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    sudo systemctl daemon-reload
    sudo systemctl restart udev
    ```
    
*   Per the [EBS CSI documentation](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md#prerequisites "https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md#prerequisites"), in order to use snapshotting abilities you must install the Kubernetes CSI snapshotter CRDs **before** the initial EBS CSI deployment (but you actually need the controller as well):
    
    *   Kubernetes CSI usage [documentation](https://github.com/kubernetes-csi/external-snapshotter#usage "https://github.com/kubernetes-csi/external-snapshotter#usage") refers to the CRDs & controller deployment process (they also mention is should be pre-installed as part of k8s distribution - EKS-D?)
        
    *   There’s no Helm chart so unless you use `kustomize` and want to clone the repository, you can just deploy with `kubectl`:
        
        *   CRDs:
            ```shell
            kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
            kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
            kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
            kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/groupsnapshot.storage.k8s.io_volumegroupsnapshotclasses.yaml
            kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/groupsnapshot.storage.k8s.io_volumegroupsnapshotcontents.yaml
            kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/groupsnapshot.storage.k8s.io_volumegroupsnapshots.yaml
            ```
            
        *   Controller (note we deploy it into the `kube-system` namespace instead of the default one):
            ```shell
            kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
            kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
            ```      
            Make sure the controller is running (and note the namespace):  
            `kubectl get -A pods -l app=snapshot-controller`
            
*   [Deploy](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md#helm "https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md#helm") the EBS CSI using Helm
    
    *   You must change the EC2 endpoint to your zCompute cluster’s hostname
        
    *   You might want to add the relevant StorageClass & VolumeSnapshotClass which are commented-out by default on the [values file](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/charts/aws-ebs-csi-driver/values.yaml#L292 "https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/charts/aws-ebs-csi-driver/values.yaml#L292"), or you can deploy them separately from one of their [examples](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/tree/master/examples/kubernetes/snapshot/manifests/classes "https://github.com/kubernetes-sigs/aws-ebs-csi-driver/tree/master/examples/kubernetes/snapshot/manifests/classes")
        
        ```shell
        helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
        helm repo update

        cat <<EOF | tee ~/values-aws-ebs-csi-driver.yaml
        controller:
        env:
            - name: AWS_EC2_ENDPOINT
              value: 'https://{zCompute_hostname}/api/v2/aws/ec2'
        EOF
        ```
        
    *   Make sure to update the values file before installing the chart:  
        `helm upgrade --namespace kube-system --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver -f ~/values-aws-ebs-csi-driver.yaml`
        
*   Validate the EBS CSI controller & nodes are running (note the namespace/s):  
    `kubectl get pods -A -l app.kubernetes.io/name=aws-ebs-csi-driver`
    
*   You can use their [examples](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/tree/master/examples/kubernetes "https://github.com/kubernetes-sigs/aws-ebs-csi-driver/tree/master/examples/kubernetes") to validate all functionalities are working…


Access a private Kubernetes cluster remotely
--------------------------------------------

For private Kuebrnetes clusters, the cluster's API server endpoint is using a private IP which is not accessible from the internet, however you can still use an SSH tunnel in order to consume it from a bastion/jump server as mentioned in [these](https://kubernetes.io/docs/tasks/extend-kubernetes/socks5-proxy-access-api/ "https://kubernetes.io/docs/tasks/extend-kubernetes/socks5-proxy-access-api/") instructions:

*   Download the kubeconfig file (originally at `/etc/kubernetes/admin.conf`) to the remote host
    
*   SSH from the remote host to the control plane VM with an added SOCKS proxy (`-D <port>`), for example:  
    `ssh -D 1080 -q -N -i <pem_file> username@kubernetes-server`
    
*   Add the `proxy-url` attribute to the downloaded file’s cluster configuration:
    ```yaml
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: LRMEMMW2 # shortened for readability 
        server: https://<API_SERVER_IP_ADRESS>:6443  # the "Kubernetes API" server, in other words the IP address of kubernetes-remote-server.example
        proxy-url: socks5://localhost:1080   # the "SSH SOCKS5 proxy" in the diagram above
    name: default
    ```
    
*   Once there and as long as the SSH tunnel runs, kubectl (or any other client) will use the proxy for all cluster operations
    
