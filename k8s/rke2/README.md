# RKE2 deployment setup

Clone this repository 

## Prerequisites: zCompute

* Storage
    * Add a "default" alias for the default storage pool (required for Terraform's volume type in step 3 - you can change this later)
* Network:
    * Networking Service Engine VPC_NATGW must be enabled
* Images
    * CentOS 7 image should be imported from the Marketplace to be used for the Bastion VM - you will need to provide Terraform with its AMI (AWS ID)
* Credentials:
    * Key-pair for the bastion server - you will need to provide Terraform with the key-pair name
    * Key-Pair for the master servers (can be the same) - you will need to provide Terraform with the key-pair name
    * Key-Pair for the worker agents (can be the same) - you will need to provide Terraform with the key-pair name
    * AWS programmatic credentials with tenant-admin & AWS MemberFullAccess permissions for the relevant (not default) project - you will need to provide Terraform/Packer with the access key & secret id

## Step 1: Automated infrastructure deployment (Terraform)
* Go to the `infra-terraform` directory
* Copy the `terraform.auto.tfvars.template` file to `terraform.auto.tfvars` and edit the parameters
    * `zcompute_api` - the URL/IP of the zCompute cluster
    * `cluster_access_key` - the tenant admin access key
    * `cluster_access_secret_id` - the tenant admin secret key
    * `bastion_key_name` - the Key-Pair for the bastion
    * `bastion_ami` - the CentOS image AMI (AWS ID)
* `terraform init` - this will initialize Terraform for the environment
* `terraform plan` - this will output the changes that Terraform will actually do (resource creation), for example:
    * VPC to hold the entire solution
    * Public subnet for the bastion VM and its corresponding Internet Gateway
    * Private subnet for the Kubernetes nodes VMs
    * Routing tables to accomodate public/private subnets
    * Default Security Group for the VPC as well as RKE2-related one (based on the SG itself)
    * Bastion VM on the public subnet (accessible to the world) with access to the private subnet (where the Kubernetes nodes will be located)
    * Network Load Balancer to hold the Kubernetes API Server endpoints - accessible to the world by default, can be hardened for Bastion-only access if you add the variable `expose_k8s_api_publicly = false`
    * Elastic IPs for the Bastion as well as the Network Load Balancer
* `terraform apply --auto-approve` - this will make the actual changes on the environment
* Due to current zCompute limitation, you will need to re-apply Terraform again in order to populate tags (resource names, etc.)
* Note that the subnets' MTU must match the edge network MTU - if there's a mismatch you should adjust the subnet MTU accordingly
* Terraform will output the relevant information required for step #3 - if you lose track of them you can always run `terraform output` to list them again
* In addition you will also be required to provide the NLB's id, private & public IPs and internal DNS name (you can get those from the GUI)


## Step 2: RKE2 image (Packer)
* Either import or create the RKE2 image
    * You can import the RKE2 1.23.4 image directly from the zCompute GUI
        * On the `images` module, click on `create`
        * Name your image and select the right project/scope
        * Select to create image from URL and use this address: `https://vsa-00000029-public-il-interoplab-01.zadarazios.com/v1/AUTH_c92d27b5fb4b4f58b4b93c267fa0f9bc/images/volume_rke2-centos-1675162676.disk1.qcow2`
    * If you wish to create your own image (and control the exact RKE2 version, etc.)
        * Make sure you have appropriate (admin-level) permissions
        * Go to the packer directory
        * Run packer as described below
        * Disregard Packer's error message about DBManager
* You will need to provide Terraform with the RKE2 AMI (AWS id)

### Creating the image directly on zCompute
This build will allow you to build the image directly on the zCompute system, using the bastion VM. 
 
Utilize the access & secret key you created before as part of the AWS CLI default profile, or set the below environment variables:
`export AWS_ACCESS_KEY_ID={access_key}`
`export AWS_SECRET_ACCESS_KEY={secret_key}`
`export AWS_DEFAULT_REGION=symphony`

Copy or rename `.auto.pkrvars.template.hcl` to `.auto.pkrvars.hcl` and provide all required variables inside it.
The following parameters should be provided:

   - `zcompute_api` - IP address or hostname of the zCompute API
   - `ami_id` - AMI ID Of a valid and accessible CentOS 7.8 Cloud image in zCompute
   - `ssh_username` - ssh username for the image
   - `subnet_id` - Subnet ID to provision the builder in (public subnet)
   - `ssh_keypair_name` - Keypair name to use for the builder
   - `private_keypair_path` - local path to the SSH private key (will be used by packer script to login in to the bastion and builder instances)

Run the packer command using: 
`packer init .`
`packer build -only=rke2-centos.amazon-ebs.centos .`

### Creating the image using a local QEMU builder
This build will allow you to build the image locally - it require a local qemu installed on the machine building the image.

Copy or rename `.auto.pkrvars.template.hcl` to `.auto.pkrvars.hcl` and provide all required variables inside it.
The following parameters should be provided:

   - `private_keypair_path` - SSH private key file to use when accessing the generated VM - 
   the public key must have the same name with `.pub` suffix 
   - `rke2_k8s_version` - Kubernetes version of the RKE2 distribution
   - `rke2_revision` - RKE2 revision

run the packer command using:`packer build -only=source.qemu.centos .`


## Step 3: Automated RKE2 deployment (Terraform)

* Go to the `rke2-terraform` directory
* Copy the `terraform.auto.tfvars.template` file to `terraform.auto.tfvars` and edit the parameters
    * `environment` - the prefix for VM names (defaults to "k8s")
    * `cluster_access_key` - the admin access key
    * `cluster_access_secret_id` - the admin secret key
    * `zcompute_api` - the URL/IP of the zCompute cluster
    * `vpc_id` - the target VPC id
    * `private_subnets_ids` - the private subnet id
    * `public_subnets_ids` - the public subnet id
    * `security_groups_ids` - the security group id to be applied on the VMs
    * `rke2_ami_id` - the RKE2 AMI (AWS ID)
    * `master_load_balancer_id` - the NLB id
    * `master_load_balancer_public_ip` -  the NLB public IP
    * `master_load_balancer_private_ip` - the NLB private IP
    * `master_load_balancer_internal_dns` - the NLB internal DNS name
    * `masters_count` - the amount of master nodes (minimal is 1, suggested 3 for HA)
    * `workers_count` - the amount of worder nodes (minimal is 0, can be later managed by cluster-autoscaler)
    * `master_key_pair` - the Key-Pair for the master VMs 
    * `worker_key_pair` - the Key-Pair for the worker VMs
* `terraform init`
* `terraform plan`
    * RKE2 master nodes ASG
    * Load Balancer target group for the master nodes ASG + public listener on 6443 for the API server
    * RKE2 worker nodes ASGs
    * Tag the existing private & public subnets for Load Balancer controller discovery
* `terraform apply`
* Due to current zCompute limitation, you will need to re-apply Terraform again in order to poplate tags (resource names, etc.)

Once Terraform is over, you will need to get the kubeconfig file from the first master node (see the [RKE2 documentation](https://docs.rke2.io/cluster_access)):
* Upload the relevant master key-pair to the bastion `~/.ssh` folder, for example: \
  <code>scp -i .ssh/{bastion_pem} .ssh/{master_pem} centos@{bastion_ip}:/home/centos/.ssh/{master_pem}</code>
* Copy the kubeconfig file from the master VM's `/etc/rancher/rke2/rke2.yaml` to your local environment, for example: \
  <code>scp -i ~/.ssh/{bastion_pem} -J centos@{bastion_ip} centos@{master_ip}:/etc/rancher/rke2/rke2.yaml ~/.kube/config</code>
* Edit the kubeconfig file and replace the cluster server element with the NLB public IP (the same one used by Terraform), for example: \
  <code>sed 's/127.0.0.1/{NLB_public_ip}/g' ~/.kube/config</code>

Use the kubeconfig to connect to the Kubernetes cluster :) 

## Step 4: Zadara Storage Class (optional)

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


## Step 5: AWS Load Balancer controller (optional)

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

## Step 6: Cluster auto-scaler (optional)
* Only relevant if you wish to enable the Kubernetes [cluster autoscaler](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md) and dynamically control your worker nodes scaling
* Deploy [cluster-autoscaler](https://github.com/kubernetes/autoscaler/tree/master/charts/cluster-autoscaler)
* Configure cluster-autoscaler with [AWS credentials](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#using-aws-credentials) (zCompute doesn't support IAM roles for Service Accounts)
* Define the workers ASG and the lower/upper bounds
