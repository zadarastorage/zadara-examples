# EKS-D deployment setup

Below is an example (not OOTB production-grade solution) for an EKS-D deployment over zCompute

## Prerequisites: zCompute

* Version
    * This automated solution will only work on zCompute release 23.08 and above
* Network:
    * Networking Service Engine VPC_NATGW must be enabled (usually already on for production clouds)
* Images:
    * Ubuntu 22.04 (or CentOS 7) image should be imported from the Marketplace to be used for the Bastion VM
    * EKS-D image (based on Ubuntu 22.04) should be imported from the below URL in order to be used for the Kubernetes nodes: \
      `https://tlv-public.s3.il-central-1.amazonaws.com/eksd-ubuntu-1690746505_1-27-8.disk1.qcow2`
* Credentials:
    * Key-pair for the bastion server (either import or create a new one)
    * Key-Pair for the master servers (can be the same)
    * Key-Pair for the worker agents (can be the same)
    * AWS programmatic credentials (access key & secret key) with tenant-admin & AWS MemberFullAccess + IAMFullAccess permissions for the relevant project

## Step 1: Automated infrastructure deployment (Terraform)
* Go to the `infra-terraform` directory
* Copy the `terraform.auto.tfvars.template` file to `terraform.auto.tfvars` and edit the parameters
    * `api_endpoint` - the URL/IP of the zCompute cluster
    * `cluster_access_key` - the tenant admin access key
    * `cluster_access_secret_id` - the tenant admin secret key
    * `bastion_key_name` - the Key-Pair for the bastion
    * `bastion_ami` - the Ubuntu/CentOS bastion image AMI (AWS ID)
    * `environment` - prefix for the various resources to be created (defaults to "k8s")
* `terraform init` - this will initialize Terraform for the environment
* `terraform plan` - this will output the changes that Terraform will actually do (resource creation), for example:
    * VPC to hold the entire solution
    * Public subnet for the bastion VM and its corresponding Internet Gateway
    * Private subnet for the Kubernetes nodes VMs
    * Routing tables to accomodate public/private subnets
    * Default Security Group for the VPC as well as RKE2-related one (based on the SG itself)
    * Bastion VM on the public subnet (**accessible to the world by default**) with access to the private subnet (where the Kubernetes nodes will be located)
    * Network Load Balancer to hold the Kubernetes API Server endpoints - accessible to the world by default, can be hardened for Bastion-only access if you add the variable `expose_k8s_api_publicly = false`
    * Elastic IPs for the Bastion as well as the Network Load Balancer
* `terraform apply --auto-approve` - this will make the actual changes on the environment
* Due to current zCompute limitation, you will need to re-apply Terraform again in order to populate some resource tags (resource names, etc.)
* Terraform will output the relevant information required for the next step - if you lose track of them you can always run `terraform output` to list them again
* In the next step you will also be required to provide the NLB's private & public IPs - you can get those from the GUI or by running the `get_loadbalancer.sh` script as proposed in the terraform output message
* Note that the subnets' MTU must match the edge network MTU - if there's a mismatch you should adjust both private & public subnets MTUs accordingly via zCompute GUI before continuing


## Step 2: Automated EKS-D deployment (Terraform)

* Go to the `rke2-terraform` directory
* Copy the `terraform.auto.tfvars.template` file to `terraform.auto.tfvars` and edit the parameters
    * Populate the sensitive variables (you may want to pass them at runtime rather than save them)
        * `cluster_access_key` - admin access key
        * `cluster_access_secret_id` - admin secret key
    * Paste the previous step's outputs (except the last `x_loadbalancer_script` entry)
        * `api_endpoint` - the URL/IP of the zCompute cluster
        * `bastion_ip` - the bastion VM's public IP
        * `environment` - Kubernetes cluster name & prefix for various resources (defaults to "k8s")
        * `masters_load_balancer_id` - the NLB id
        * `masters_load_balancer_internal_dns` - the NLB internal DNS name
        * `private_subnet_id` - the private subnet id (in which all of the VMs will be created)
        * `public_subnet_id` - "the public subnet id (in which the NLB will listen)
        * `security_group_id` - the security group id to be applied on all VMs
        * `vpc_id` - the target VPC id
    * Paste the NLB private & public IP addresses (can be fetched by running the `get_loadbalancer.sh` script)
        * `masters_load_balancer_private_ip` - the NLB private IP
        * `masters_load_balancer_public_ip` - the NLB public IP
    * Populate extra mandatory variables
        * `eksd_ami_id` - the EKS-D AMI (AWS ID)
        * `master_key_name` - the Key-Pair name for the master VMs (you may reuse the bastion key)
        * `worker_key_name` - the Key-Pair name for the worker VMs (you may reuse the bastion key)
    * Populate extra optional variables
        * `masters_count` - the amount of master nodes (minimal is 1, suggested 3 for HA)
        * `workers_count` - the amount of worder nodes (minimal is 0, can be later managed by cluster-autoscaler)
        * `masters_instance_type` - the masters VM size (minimal is z2.large, suggested z4.xlarge)
        * `masters_instance_type` - the workers VM size (minimal is z2.large, suggested z8.xlarge)
        * `masters_volume_size` - the masters disk size (minimal is 25GB, suggested 100GB)
        * `workers_volume_size` - the workers disk size (minimal is 25GB, suggested 250GB)
* `terraform init` - this will initialize Terraform for the environment
* `terraform plan` - this will output the changes that Terraform will actually do (resource creation), for example:
    * EKS-D master nodes ASG + Launch Configuration
    * Load Balancer target group for the master nodes ASG + publish listener on 6443 for the API server
    * EKS-D worker nodes ASGs + Launch Configuration
    * Tag the existing private & public subnets for Load Balancer controller discovery
* `terraform apply` - this will make the actual changes on the environment

Once Terraform is over, you will need to get the kubeconfig file from the first master node - you can use the `get_kubeconfig.sh` script as mentioned on the `terraform output` in order to fetch the initial kubeconfig from the first master node (through the bastion) into the project's directory. 

Use the kubeconfig to connect to the Kubernetes cluster - it comes with the below OOTB deployments:
* CCM - using the AWS Cloud Provider, providing you the below abilities:
    * Instances lifecycle updates (Kubernetes will be aware of new/removed Kubernetes nodes)
    * Instances information labeling (Kubernetes will show Instance information as node labels)
    * LoadBalancer abilities (NLB only, for ALB you'll need to deploy the AWS Load Balancer Controller)
        * Add the below annotation for all LoadBalancer specifications: \
          `service.beta.kubernetes.io/aws-load-balancer-type: nlb`
        * Add the below annotation for all public-facing NLBs (the default is internal-facing): \
          `service.beta.kubernetes.io/aws-load-balancer-internal: "false"`
* CNI - using Flannel, providing basic pod networking abilities 
    * You may switch to Calico - TBD
* CSI - using the EBS driver, providing block persistance abilities:
    * The `ebs-cs` StorageClass is pre-configured (note it is not set as the default StorageClass, so you may override it with other CSIs)
    * You can mark `ebs-sc` as the default (implicit) StorageClass by setting the `storageclass.kubernetes.io/is-default-class` annotation to `true`: \
      `kubectl patch storageclass ebs-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'`
    * The snapshotting abilities are pre-configured with the `csi-aws-vsc` VolumeSnapshotClass

## Optional: Make your own EKS-D image (Packer)
Inside the packer folder you will find a build project which will allow you to build the EKS-D image directly on the zCompute system, using the bastion VM. 
 
* Utilize the access & secret key you created before as part of the AWS CLI default profile, or set the below environment variables:
  `export AWS_ACCESS_KEY_ID={access_key}`
  `export AWS_SECRET_ACCESS_KEY={secret_key}`
  `export AWS_DEFAULT_REGION=symphony`

* Copy or rename `.auto.pkrvars.template.hcl` to `.auto.pkrvars.hcl` and provide all required variables inside it.
  The following parameters should be provided:
   * `api_endpoint` - IP address or hostname of the zCompute API
   * `ssh_bastion_username` - the bastion user
   * `bastion_public_ip` - the bastion public IP
   * `ami_id` - AMI ID of a valid and accessible Ubuntu 22.04 machine image in zCompute's images
   * `ssh_username` - ssh username for the image
   * `subnet_id` - Subnet ID to provision the builder in (public subnet)
   * `ssh_keypair_name` - Keypair name to use for the builder
   * `private_keypair_path` - local path to the SSH private key (will be used by packer script to login in to the bastion and builder instances)

* Run the packer command using: 
  ```shell
  packer init .
  packer build .
  ```


## Optional: Zadara CSI
Only relevant if you wish to utilize the Zadara CSI and use a VPSA to persist data from your Kubernetes

* Requires a dedicated VPSA with one pool and a write-enabled user token (access key) - you will need to provide the key to the Zadara CSI Storage Class configuration
* Make sure routing is in place and Security Group allows communication between the private subnet and the VPSA
* Add the [Zadara CSI](https://github.com/zadarastorage/zadara-csi) Helm repo: \
  <code>helm repo add zadara-csi https://raw.githubusercontent.com/zadarastorage/zadara-csi/release/zadara-csi-helm</code>
* Deploy the CSI driver chart - see values [here](https://github.com/zadarastorage/zadara-csi/blob/release/deploy/helm/zadara-csi/values.yaml) and note you may want to disable TLS verification for internal VPSAs, for example: \
  <code>helm upgrade --install zadara-csi zadara-csi/zadara-csi --set vpsa.verifyTLS=false</code>
* Follow the post-deployment Helm notes for the CRDs definitions:
    * [VSCStorageClass](https://github.com/zadarastorage/zadara-csi/blob/release/deploy/examples/vscstorageclass.yaml) configuration (see full documentation [here](https://github.com/zadarastorage/zadara-csi/blob/release/docs/configuring_vsc.md))
    * [VPSA](https://github.com/zadarastorage/zadara-csi/blob/release/deploy/examples/vpsa.yaml) configuration (there goes the VPSA address & the user's token)
* Deploy a [Storage Class](https://github.com/zadarastorage/zadara-csi/blob/release/docs/configuring_storage.md) which will point to the VSCStorageClass (you might want to set it as the default storage class for simplicity)
* Further CSI examples (like how to create a block/filesystem PVC, etc.) can be found [here](https://github.com/zadarastorage/zadara-csi/tree/release/deploy/examples)


## Optional: AWS Load Balancer controller
Only relevant if you wish to use the [AWS Load Balancer controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller) for ingress controller

* Add the [AWS Load Balancer controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller/tree/main/helm/aws-load-balancer-controller) Helm repo: \
  <code>helm repo add eks [https://aws.github.io/eks-charts](https://aws.github.io/eks-charts)</code>
* Create value file named <code>values.yaml</code> according to the below specification (remember to update all of the cluster's hostname parameters with the zCompute URL):
  ```yaml
  clusterName:  # cluster name (terraform's "environment" variable from step #3)
  vpcId: # cluster's vpc id
  awsApiEndpoints: "ec2=https://<cluster_hostname>/api/v2/aws/ec2,elasticloadbalancing=https://<cluster_hostname>/api/v2/aws/elbv2,acm=https://<cluster_hostname>/api/v2/aws/acm,sts=https://<cluster_hostname>/api/v2/aws/sts"
  enableShield: false
  enableWaf: false
  enableWafv2: false
  region: eu-west-1
  ```
* Deploy the controller: \
  <code>helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller -f values.yaml -n kube-system</code>
* For NLB - use the LoadBalancer service per the [documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/annotations)
  * Make sure to add the following annotations to the service - the first two are mandatory in order for the controller to function, and the third is only required for internet-facing NLB (as the default is internal):
    ```yaml
    service:
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: instance
        service.beta.kubernetes.io/aws-load-balancer-type: external
        service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    ```
  * As a [known limitation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/nlb/#security-group), the controller wouldn't create the relevant security group to the NLB - rather, it will add the relevant rules to the worker node's security group and you can attach this (or another) security group to the NLB via the zCompute GUI, AWS CLI or Symp
* For ALB - use the Ingress resource per the [documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations)
  * Set the `ingressClassName` attribute per the controller class name (default is `alb`) 
  * By default all Ingress resources are [internal-facing](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations/#scheme) - if you want your ALB to get a public IP you will have to set the `alb.ingress.kubernetes.io/scheme` annotation to `internet-facing` (default value is `internal`)


## Optional: Cluster auto-scaler
Only relevant if you wish to enable the Kubernetes [cluster autoscaler](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md) and dynamically control your worker nodes scaling

* Add the [cluster-autoscaler](https://github.com/kubernetes/autoscaler/tree/master/charts/cluster-autoscaler) Helm repo: \
  <code>helm repo add autoscaler https://kubernetes.github.io/autoscaler</code>
* Make sure you use the latest cluster-autoscaler release (zCompute support was introduced in 1.26.0 but 1.24.0 is still the default image tag on the chart)
* Configure cluster-autoscaler for AWS per [the documentation](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#cluster-autoscaler-on-aws)
  * The default `cloudProvider` value is `aws` so no need to change that
  * If you opt to use the [auto-discovery mode](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#auto-discovery-setup) - remember to add the relevant tags on the relevant ASG/s (either from zCompute GUI, AWS CLI or Symp) - the default ones are `k8s.io/cluster-autoscaler/enabled` and `k8s.io/cluster-autoscaler/<cluster-name>` where cluster-name is the environment variable set on the rke2-terraform project
  * If you opt to use the [manual mode](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#manual-configuration)  - remember to define the specific workers ASG/s name/s and their lower/upper bounds on the [autoscalingGroups](https://github.com/kubernetes/autoscaler/blob/master/charts/cluster-autoscaler/values.yaml#L39) values
* Make sure your values refer to the pre-populated cloud-config ConfigMap as mentioned on the [documentation](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#using-cloud-config-with-helm):
    ```yaml
    cloudConfigPath: config/cloud.conf

    extraVolumes:
      - name: cloud-config
        configMap:
          name: cloud-config

    extraVolumeMounts:
      - name: cloud-config
        mountPath: config
    ```
