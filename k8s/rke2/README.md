# RKE2 deployment setup

Below is an example (not OOTB production-grade solution) for an RKE2 deployment over zCompute

## Prerequisites: zCompute

* Storage
    * Add a "default" alias for the default storage pool (required for Terraform's volume type in step 3 - you can change this later)
* Network:
    * Networking Service Engine VPC_NATGW must be enabled (usually already on for customer clouds)
* Images
    * CentOS 7 image should be imported from the Marketplace to be used for the Bastion VM - you will need to provide Terraform with its AMI (AWS ID)
* Credentials:
    * Key-pair for the bastion server - you will need to provide Terraform with the key-pair name
    * Key-Pair for the master servers (can be the same) - you will need to provide Terraform with the key-pair name
    * Key-Pair for the worker agents (can be the same) - you will need to provide Terraform with the key-pair name
    * AWS programmatic credentials with tenant-admin & AWS MemberFullAccess + IAMFullAccess permissions for the relevant (not default) project - you will need to provide Terraform/Packer with the access key & secret id

## Step 1: Automated infrastructure deployment (Terraform)
* Go to the `infra-terraform` directory
* Copy the `terraform.auto.tfvars.template` file to `terraform.auto.tfvars` and edit the parameters
    * (optional) `environment` - prefix for the various resources to be created (defaults to "k8s")
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
    * Bastion VM on the public subnet (**accessible to the world by default**) with access to the private subnet (where the Kubernetes nodes will be located)
    * Network Load Balancer to hold the Kubernetes API Server endpoints - accessible to the world by default, can be hardened for Bastion-only access if you add the variable `expose_k8s_api_publicly = false`
    * Elastic IPs for the Bastion as well as the Network Load Balancer
* `terraform apply --auto-approve` - this will make the actual changes on the environment
* Due to current zCompute limitation, you will need to re-apply Terraform again in order to populate tags (resource names, etc.)
* Note that the subnets' MTU must match the edge network MTU - if there's a mismatch you should adjust both private & public subnets MTUs accordingly via zCompute GUI before step #3
* Terraform will output the relevant information required for step #3 - if you lose track of them you can always run `terraform output` to list them again
* In addition you will also be required to provide the NLB's private & public IPs (you can get those from the GUI)


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
    * (optional) `environment` - cluster name & prefix for the various resources to be created (defaults to "k8s")
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

## Step 4: Zadara CSI (optional)

* Only relevant if you wish to utilize the Zadara CSI and use a VPSA to persist data from your Kubernetes
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


## Step 5: AWS Load Balancer controller (optional)

* Only relevant if you wish to use the [AWS Load Balancer controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller) for ingress controller
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
  env:
    AWS_ACCESS_KEY_ID:
    AWS_SECRET_ACCESS_KEY:
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


## Step 6: Cluster auto-scaler (optional)
* Only relevant if you wish to enable the Kubernetes [cluster autoscaler](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md) and dynamically control your worker nodes scaling
* Add the [cluster-autoscaler](https://github.com/kubernetes/autoscaler/tree/master/charts/cluster-autoscaler) Helm repo: \
  <code>helm repo add autoscaler https://kubernetes.github.io/autoscaler</code>
* Make sure you use the latest cluster-autoscaler release (zCompute support was introduced in 1.26.0 but 1.24.0 is still the default image tag on the chart)
* Configure cluster-autoscaler for AWS per [the documentation](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#cluster-autoscaler-on-aws)
  * The default `cloudProvider` value is `aws` so no need to change that
  * If you opt to use the [auto-discovery mode](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#auto-discovery-setup) - remember to add the relevant tags on the relevant ASG/s (either from zCompute GUI, AWS CLI or Symp) - the default ones are `k8s.io/cluster-autoscaler/enabled` and `k8s.io/cluster-autoscaler/<cluster-name>` where cluster-name is the environment variable set on the rke2-terraform project
  * If you opt to use the [manual mode](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#manual-configuration)  - remember to define the specific workers ASG/s name/s and their lower/upper bounds on the [autoscalingGroups](https://github.com/kubernetes/autoscaler/blob/master/charts/cluster-autoscaler/values.yaml#L39) values
  * You can implicitly let cluster-autoscaler use the worker node's instance profile (it was set by Terraform and has the relevant permissions) or you can explicitly provide it with a dedicated set of [AWS credentials](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#using-aws-credentials) as values (see [example](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/examples/values-cloudconfig-example.yaml)) as zCompute doesn't support OIDC like EKS does
* Create & deploy the cloud-config ConfigMap per the [documentation](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#using-cloud-config-with-helm) - make sure to list the zCompute's AWS URL endpoints as mentioned on the [example file](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/examples/configmap-cloudconfig-example.yaml) (you can pick any region as long as the URL points to your zCompute cluster's URL), for example:
```yaml
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
      URL=https://<zcompute_url>/api/v2/aws/ec2
      SigningRegion=us-east-1
    [ServiceOverride "autoscaling"]
      Service=autoscaling
      Region=us-east-1
      URL=https://<zcompute_url>/api/v2/aws/autoscaling
      SigningRegion=us-east-1
```
* Make sure your values refer to the cloud-config ConfigMap as mentioned on the [documentation](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#using-cloud-config-with-helm):
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
