# RKE2 deployment setup

## Prerequisites: zCompute

* VPC:
    * Public subnet (for the bastion VM)
    * Private subnet (for the Kubernetes nodes VMs) - you will need to provide Terraform with the id
    * Security Group should enable all internal traffic (using the group)
* Credentials:
    * Key-Pair for the master servers - you will need to provide Terraform with the name
    * Key-Pair for the worker agents (can be the same one as the master one) - you will need to provide Terraform with the name
    * AWS programmatic credentials with admin permissions - you will need to provide Terraform/Packer with the access key & secret id

## Step 1: Bastion VM
* Accessible VM (on the public subnet) with access to the private subnet (where the actual Kubernetes nodes are located)
* You can use a dedicated key-pair or reuse the Kubernetes master/worker one, depending on your security concerns
* Security Group should allow incoming SSH communication (port 22) from the world
* Attach an elastic IP to the bastion so you can easily access it

## Step 2: RKE2 image (Packer)
* Either import or create the RKE2 image
    * You can import the RKE2 1.23.4 image directly from the zCompute GUI
        * On the `images` module, click on `create`
        * Name your image and select the right project/scope
        * Select to create image from URL and use this address: `s3://confimage1/centos-7.8-rke2-v1.23.4-rke2r1.qcow2`
    * If you wish to create your own image
        * Make sure you have appropriate (admin-level) permissions
        * Run packer as described below
        * Disregard Packer's error message about DBManager
* You will need to provide Terraform with the cluster’s AMI (AWS ids)

### Creating the image directly on zCompute
This build will allow you to build the image directly on the zCompute system.
It requires access to the zCompute API.
 
1. Provision a bastion host with a keypair of your choice and attach an elastic IP to it.
1. Copy or rename `.auto.pkrvars.template.hcl` to `.auto.pkrvars.hcl` and provide all required variables inside it. </br>
   The following parameters should be provided:

   - `zcompute_api` - IP address or hostname of the zCompute API
   - `ami_id` - AMI ID Of a valid and accessible CentOS 7.8 Cloud image in zCompute
   - `ssh_username` - ssh username for the image
   - `subnet_id` - Subnet ID to provision the builder in
   - `ssh_keypair_name` - Keypair name to use for the builder
   - `private_keypair_path` - This SSH private key will be used by packer script to login in to the bastion and builder instances.

   > There are other parameters that can be modified, please consult with their description in `variables.pkr.hcl` file.

run the packer command using: `packer build -only=rke2-centos.amazon-ebs.centos [-var "name1=value1" [-var "name2=value2"]] .`

### Creating the image using a local QEMU builder
This build will allow you to build the image locally. 
it require a local qemu installed on the machine building the image
Copy or rename `.auto.pkrvars.template.hcl` to `.auto.pkrvars.hcl` and provide all required variables inside it. </br>
The following parameters should be provided:

   - `private_keypair_path` - SSH private key file to use when accessing the generated VM - 
   the public key must have the same name with `.pub` suffix 
   - `rke2_k8s_version` - Kubernetes version of the RKE2 distribution
   - `rke2_revision` - RKE2 revision

run the packer command using:`packer build -only=source.qemu.centos [-var "name1=value1" [-var "name2=value2"]] .`


## Step 3: Load Balancer

* Create NLB on the cluster's relevant subnet & Security Group - make sure it has high-availability
* You will need to provide Terraform with the below NLB information:
    * LB id
    * Private IP
    * Public IP
    * Internal DNS

## Step 3: Automated RKE2 deployment (Terraform)

* Terraform init
* Terraform plan
* Terraform apply
    * RKE2 master nodes ASG
    * Load Balancer target group for the master nodes ASG + public listener on 6443 for the API server
    * RKE2 worker nodes ASGs
    * Tag the existing private & public subnets for Load Balancer controller discovery

## Step 4: Calico IPIP (optional)

* Only relevant if you wish to switch the default CNI from VXLAN to IPIP
* Get the first Master's internal IP
* Fetch the kube.conf in order to be able and use kubectl/calicoctl
* Switch Calico from the default VXLAN to IPIP:
  * After the installation of the RKE2 master node we need to apply the following config \
    <code>kubectl apply -f rke2-calico-config.yaml</code>
    ```yaml
      apiVersion: helm.cattle.io/v1
      kind: HelmChartConfig
      metadata:
       name: rke2-calico
       namespace: kube-system
      spec:
       valuesContent: |-
         installation:
           calicoNetwork:
             bgp: Enabled
             ipPools:
             - blockSize: 24
               cidr: ${ calico_cidr }
               encapsulation: IPIP
               natOutgoing: Enabled
    ```
  * use kubectl to apply the BGP configuration <strong><em>kubectl apply -f bgpconfiguration.yaml</em></strong>
    ```yaml
    apiVersion: crd.projectcalico.org/v1
    kind: BGPConfiguration
    metadata:
     name: default
    spec:
     asNumber: 64512
     listenPort: 179
     logSeverityScreen: Info
     nodeToNodeMeshEnabled: true
    ```
  * Edit the default IP Pool resource (<strong><em>kubectl edit ippools default-ipv4-ippool</em></strong>) and make sure that <strong><em>vxlanMode</em></strong> is set to <strong><em>Never</em></strong> and <strong><em>ipipMode</em></strong> is set to <strong><em>Always</em></strong>
    ```yaml
    apiVersion: crd.projectcalico.org/v1
    kind: IPPool
    metadata:
     name: default-ipv4-ippool
    spec:
     allowedUses:
     - Workload
     - Tunnel
     blockSize: 24
     cidr: 10.42.0.0/16
     ipipMode: Always
     natOutgoing: true
     nodeSelector: all()
     vxlanMode: Never
    ```
  * Edit the FelixConfiguration resource (<strong><em>kubectl edit FelixConfiguration default</em></strong>) and make sure that <strong><em>ipipEnabled</em></strong> is set to <strong><em>true</em></strong> and <strong><em>vxlanEnabled</em></strong> is <strong>not</strong> present. 
    ```yaml
    apiVersion: crd.projectcalico.org/v1
    kind: FelixConfiguration
    metadata:
     annotations:
       meta.helm.sh/release-name: rke2-calico
       meta.helm.sh/release-namespace: kube-system
     labels:
       app.kubernetes.io/managed-by: Helm
     name: default
    spec:
     bpfLogLevel: ""
     featureDetectOverride: ChecksumOffloadBroken=true
     ipipEnabled: true
     logSeverityScreen: Info
     reportingInterval: 0s
     wireguardEnabled: false
    ```
  * After completing all the above steps, restart the DaemonSet of the calico-node: \
  <code>kubectl delete pods -l k8s-app=calico-node -n calico-system</code>

  * In order to validate that the pods are using IPIP follow these steps:
    * Run 2 pods on separate nodes.
    * Ping between those 2 pods.
    * SSH into one of the nodes and use tcpdump command against the eth0 interface: \
      <code>sudo tcpdump -vvnneSs 0 -i eth0 not port 22</code>

    See this example output: \
    15:32:41.630575 fa:16:3e:98:a9:67 > fa:16:3e:bf:b0:3c, ethertype IPv4 (0x0800), length 118: (tos 0x0, ttl 63, id 14377, offset 0, flags [none], <strong>proto IPIP (4)</strong>, length 104)
	  10.0.16.7 > 10.0.16.22: (tos 0x0, ttl 63, id 53293, offset 0, flags [none], proto ICMP (1), length 84)
	  10.42.185.7 > 10.42.0.27: ICMP echo reply, id 21, seq 151, length 64

## Step 5: Zadara Storage Class (optional)

* Only relevant if you wish to utilize the Zadara CSI and use a VPSA to persist data from your Kubernetes
* Requires a dedicated VPSA with 1 pool and programmatic credentials (access key) - you will need to provide the access key to the Zadara CSI Storage Class configuration
* Make sure routing is in place and Security Group allows communication between the private subnet and the VPSA
* Deploy the Zadara CSI V2
    * Clone the [zadara-csi](https://github.com/zadarastorage/zadara-csi) repository
    * Checkout the master branch and get the chart: \
      https://github.com/zadarastorage/zadara-csi/tree/master/deploy/helm/zadara-csi
* Note the post deployment Helm notification for the CRDs definitions:
    * Follow the Zadara CSI documentation to configure [VSC](https://github.com/zadarastorage/zadara-csi/blob/master/docs/configuring_vsc.md) (with the VPSA hostname/IP and access key) 
    * Follow the Zadara CSI documentation to configure [Storage Class](https://github.com/zadarastorage/zadara-csi/blob/master/docs/configuring_storage.md)


## Step 6: AWS Load Balancer controller (optional)

* Only relevant if you wish to use the [AWS Load Balancer controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller) for ingress controller
* Add the [AWS Load Balancer controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller/tree/main/helm/aws-load-balancer-controller) Helm repo: \
  <code>helm repo add eks [https://aws.github.io/eks-charts](https://aws.github.io/eks-charts)</code>
* Create value file named <code>values.yaml</code> according to the below specification (remember to update the cluster's hostname with the zCompute URL):
  ```yaml
  clusterName:  # cluster name
  vpcId: # cluster's vpc id
  image:
    repository: amazon/aws-alb-ingress-controller
  awsApiEndpoints: "ec2=https://<cluster_hostname>/api/v2/aws/ec2,elasticloadbalancing=https://<cluster_hostname>/api/v2/aws/elbv2,acm=https://<cluster_hostname>/api/v2/aws/acm,sts=https://<cluster_hostname>/api/v2/aws/sts"
  enableShield: false
  enableWaf: false
  enableWafv2: false
  region: eu-west-1
  env:
    AWS_ACCESS_KEY_ID:
    AWS_SECRET_ACCESS_KEY:
  ```
* Deploy the controller: \
  <code>helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller -f values.yaml -n kube-system</code>
* Deploy your ingress controller (for example, nginx) and configure it with the following:
  ```yaml
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: instance
      service.beta.kubernetes.io/aws-load-balancer-type: external
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
  ```
  The AWS Load Balancer Controller documentation, including specific annotations can be found here:
  * [Ingress](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations)
  * [Service](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/annotations)

## Step 7: Cluster auto-scaler (optional)
* Only relevant if you wish to enable the Kubernetes [cluster autoscaler](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md) and dynamically control your worker nodes scaling
* Create a dedicated AWS role with the required permissions
* Create an instance profile 
