# EKS-D automated deployment
Below is an example (not OOTB production-grade solution) for an EKS-D automated deployment over zCompute - facilitating cloud integration with dynamic ASG scaling, instance labeling & lifecycle, native load balancing, built-in storage capabilities and optional Kasten K10 as a backup & restore solution. 

## Known limitations
* zCompute minimal version is **23.08** (previous versions will not support the EKS-D initialization phase which is implemented in Step #2) in VSC-mode
* EBS CSI requires modifying the [udev service](https://manpages.ubuntu.com/manpages/jammy/man7/udev.7.html), allowing API calls to be made upon new volume attachment
* Upgraded zCompute clouds must have at least one AWS-compatible VolumeType API Alias (io1 / io2 / gp2 / gp3 / sc1 / st1 / standard / sbp1 / sbg1) to be available for provisioning (fresh 23.08 installations have them OOTB)
* EKS-D cluster name (set by the `environment` variable as mentioned below) must be unique for the account
* The deployment will create a bastion VM with port 22 (SSH) exposed to the world (and EKS-D nodes with port 22 exposed to the bastion) - you may want to limit the exposure, stop or even terminate the bastion VM post-deployment
* The Cluster Autoscaler might also scale-down the control-plane ASG, so make sure to use min=max=desired for the ASG capacity (default is 1)

## Prerequisites: zCompute
* Storage:
    * Verify your provisioning-enabled VolumeType aliases - ask your cloud admin or run the below Symp command (via the Zadara toolbox VM or the symp-cli [container](https://hub.docker.com/r/stratoscale/symp-cli)) using your zCompute account (domain) and credentials: \
    `volume volume-types list -c name -c alias -c operational_state -c health -m grep=ProvisioningEnabled` \
    The EBS CSI will use 'gp2' as the default VolumeType unless specified otherwise via the terraform `ebs_csi_volume_type` variable in the eksd-terraform project
* Images:
    * Ubuntu 22.04 image should be imported from the Marketplace to be used for the Bastion VM
    * Zadara's pre-baked EKS-D image should be imported from the Marketplace to be used for the Kubernetes nodes
* Credentials:
    * Key-pair for the bastion server (either import or create a new one)
    * Key-Pair for the master servers (can be the same)
    * Key-Pair for the worker agents (can be the same)
    * AWS programmatic credentials (access key & secret key) with tenant-admin, AWS MemberFullAccess & IAMFullAccess permissions for the relevant project

## All-In-One deployment
For a simplified/demo experience, you can use this option to streamline a cluster deployment with a single command - you will get the OOTB default values of a small-sized cluster with a basic CNI (Flannel) and all addons except for Kasten K10. Note this option should not be used for production-grade deployments (for example the default control-plane is not HA), however you may change the default values as mentioned below to use this approach for any cluster configuration. 

* Copy the `terraform.tfvars.template` file to `terraform.tfvars` and edit the parameters:
    * `api_endpoint` - the URL/IP of the zCompute cluster
    * `environment` - prefix for the various resources to be created (defaults to "k8s")
    * `bastion_keyname` - the bastion Key-Pair name
    * `bastion_keyfile` - the bastion Key-Pair private PEM file location
    * `bastion_ami` - the Ubuntu/CentOS bastion image AMI (AWS ID)
    * `bastion_user` - depending on the bastion AMI (either ubuntu or centos)
    * `eksd_ami` - the pre-baked EKS-D image AMI (AWS ID)
    * `masters_keyname` - the masters Key-Pair name
    * `masters_keyfile` - the masters Key-Pair private PEM file location
    * `workers_keyname` - the workers Key-Pair name
    * `workers_keyfile` - the workers Key-Pair private PEM file location
* Optional - create a non-default deployment
    * Check the below infra-terraform & eksd-terraform projects for their specific variables and their default values in the respected `variables.tf` files, or set an environment variable `TF_VAR_<variable name>=<value>` before your run
    * For example, you can set the `ebs_csi_volume_type` variable in the eksd-terraform project to something other than 'gp2' per your storage preferences
* Run `apply-all.sh <access_key> <secret_key>` with your access_key & secret_key as the parameters (or set the AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY environment variables before running the script without specifying parameters)
    * The script will take about 10 minutes for a successful minimal deployment of a single master & worker
    * The script can be rerun for re-apply Terraform changes (for example as part of an upgrade procedure)
    * If neccessary, you can destroy all assets and reset everything with the `destroy-all.sh` script (with the same two credentials parameters/variables)
* Once completed you will see the kubeconfig content ready for your usage (presented on screen and as a kubeconfig file in the running directory) so you can skip the next two steps and use it as-is ;-) 

## Step 1: Automated infrastructure deployment (Terraform)
* Go to the `infra-terraform` directory
* Copy the `terraform.auto.tfvars.template` file to `terraform.auto.tfvars` and edit the parameters
    * `api_endpoint` - the URL/IP of the zCompute cluster
    * `cluster_access_key` - the tenant admin access key
    * `cluster_access_secret_id` - the tenant admin secret key
    * `bastion_keyname` - the Key-Pair for the bastion
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
    * Network Load Balancer to hold the Kubernetes API Server endpoints - accessible to the world by default, can be hardened for internal-only access if you add the variable `expose_k8s_api_publicly = false`
    * Elastic IPs for the Bastion as well as the Network Load Balancer
* `terraform apply --auto-approve` - this will make the actual changes on the environment
* Due to current zCompute limitation, you will need to re-apply Terraform again in order to populate some resource tags (resource names, etc.)
* Terraform will output the relevant information required for the next step - if you lose track of them you can always run `terraform output` to list them again
* In the next step you will also be required to provide the NLB's private & public IPs - you can get those from the GUI or by running the `get_loadbalancer.sh` script as proposed in the terraform output message
* Note that the subnets' MTU must match the edge network MTU - if there's a mismatch you should adjust both private & public subnets MTUs accordingly via zCompute GUI before continuing

## Step 2: Automated EKS-D deployment (Terraform)
* Go to the `eksd-terraform` directory
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
        * `masters_count` - the amount of master nodes (minimal is 1, defaulting to 1 but suggested 3 for HA)
        * `workers_count` - the amount of worder nodes (minimal is 0, defaulting to 1 + 3 more for max ASG size of 4)
        * `masters_instance_type` - the masters VM size (minimal is z2.large, defaulting to z4.large)
        * `masters_instance_type` - the workers VM size (minimal is z2.large, defaulting to z8.large)
        * `masters_volume_size` - the masters disk size (minimal is 25GB, defaulting to 50GB)
        * `workers_volume_size` - the workers disk size (minimal is 25GB, defaulting to 100GB)
        * `cni_provider` - choose the CNI from a list of flannel (default), calico or cilium (experimental)
        * `ebs_csi_volume_type` - the cloud's storage VolumeType (defaulting to gp2)
        * `install_ebs_csi` - whether to deploy the EBS CSI driver addon (defaulting to true)
        * `install_lb_controller` - whether to deploy the AWS Load Balancer Controller addon (defaulting to true)
        * `install_autoscaler` - whether to deploy the Cluster Autoscaler addon (defaulting to true)
        * `install_kasten_k10` - whether to deploy the Kasten K10 addon (defaulting to false)
* `terraform init` - this will initialize Terraform for the environment
* `terraform plan` - this will output the changes that Terraform will actually do (resource creation), for example:
    * EKS-D master nodes ASG + Launch Configuration
    * Load Balancer target group for the master nodes ASG + publish listener on 6443 for the API server
    * EKS-D worker nodes ASGs + Launch Configuration
    * Tag the existing private & public subnets for Load Balancer controller discovery
* `terraform apply` - this will make the actual changes on the environment

Once Terraform is over, you will need to get the kubeconfig file from the first master node - you can use the `get_kubeconfig.sh` script as mentioned on the `terraform output` in order to fetch the initial kubeconfig from the first master node (through the bastion) into the project's directory.

Use the kubeconfig to connect to the Kubernetes cluster in the usual way - congratulations on your new cluster :) 

## OOTB deployments
Your cluster comes pre-deployed with the below utilities:

* CCM - using the AWS Cloud Provider, providing you the below abilities:
    * Instances lifecycle updates (Kubernetes will be aware of new/removed Kubernetes nodes)
    * Instances information labeling (Kubernetes will show EC2 Instance information as node labels)
    * LoadBalancer [abilities](https://github.com/kubernetes/cloud-provider-aws/blob/master/docs/service_controller.md) - note this is NLB only, and the AWS Load Balancer Controller addon will override this specification if enabled
        * Add the below annotation for all LoadBalancer specifications: \
          `service.beta.kubernetes.io/aws-load-balancer-type: nlb`
        * Add the below annotation for all public-facing NLBs (the default is internal-facing): \
          `service.beta.kubernetes.io/aws-load-balancer-internal: "false"`
* CNI - either Flannel (default), Calico or Cilium 
    * [Flannel](https://github.com/flannel-io/flannel) - basic pod networking abilities, suitable for most use-cases
    * [Calico](https://docs.tigera.io/) - advanced security (may require further configuration)
    * [Cilium](https://cilium.io/) - eBPF-based networking with built-in observability (experimental)

## Addons
As mentioned in step 2, your cluster can come pre-deployed with the latest versions (at the time of EKS-D image baking) of the below addons. Alternatively, you may change/delete them via helm after the deployment, or choose to install them by yourself:

* EBS CSI driver (enabled by default):
    * The `ebs-cs` StorageClass is pre-configured with the VolumeType and set as the default StorageClass (you may [override](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/) it with other CSIs)
    * The snapshotting abilities are pre-configured with the `ebs-vsc` VolumeSnapshotClass (including the Kasten-ready [annotation](https://docs.kasten.io/latest/install/storage.html#csi-snapshot-configuration) for seamless operability)
    * For self-installation, use the below values with the helm chart: 
        ```yaml
        controller:
          env:
            - name: AWS_EC2_ENDPOINT
              value: '<API_ENDPOINT>/api/v2/aws/ec2'
            - name: AWS_REGION
              value: 'us-east-1'
        storageClasses:
          - name: ebs-sc
            annotations:
              storageclass.kubernetes.io/is-default-class: "true"
            parameters:
              type: "<EBS ALIAS>"
        volumeSnapshotClasses: 
          - name: ebs-vsc
            annotations:
              snapshot.storage.kubernetes.io/is-default-class: "true"
              k10.kasten.io/is-snapshot-class: "true"
            deletionPolicy: Delete
        ```
* AWS Load Balancer Controller (enabled by default)
    * For NLB - use the LoadBalancer service per the [documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/annotations)
      * The latest controller version overrides the built-in LoadBalancer resource, so you just need to add the `service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing` annotation for internet-facing NLB (as the default is internal)
      * As a [known limitation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/service/nlb/#security-group), the controller wouldn't create the relevant security group to the NLB - rather, it will add the relevant rules to the worker node's security group and you can attach this (or another) security group to the NLB via the zCompute GUI, AWS CLI or Symp
    * For ALB - use the Ingress resource per the [documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/ingress/annotations)
      * By default all Ingress resources are [internal-facing](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/ingress/annotations/#scheme) - if you want your ALB to get a public IP you will have to add the `alb.ingress.kubernetes.io/scheme: internet-facing` annotation
    * For self-installation, use the below values with the helm chart: 
      ```yaml
      clusterName: <CLUSTER_NAME>
      vpcId: <VPC_ID>
      awsApiEndpoints: "ec2=<API_ENDPOINT>/api/v2/aws/ec2,elasticloadbalancing=<API_ENDPOINT>/api/v2/aws/elbv2,acm=<API_ENDPOINT>/api/v2/aws/acm,sts=<API_ENDPOINT>/api/v2/aws/sts"
      enableShield: false
      enableWaf: false
      enableWafv2: false
      region: us-east-1
      ingressClassConfig:
        default: true
      ```
* Cluster Autoscaler (enabled by default)
    * The configuration is pre-populated to use the [auto-discovery mode](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#auto-discovery-setup) based on the pre-populated tags on the worker ASG (`k8s.io/cluster-autoscaler/enabled` and `k8s.io/cluster-autoscaler/<cluster-name>`) where cluster-name is the environment variable set on the eksd-terraform project
    * If you opt to use the [manual mode](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#manual-configuration)  - remember to define the specific workers ASG/s name/s and their lower/upper bounds on the [autoscalingGroups](https://github.com/kubernetes/autoscaler/blob/master/charts/cluster-autoscaler/values.yaml#L39) values
    * For self-installation, use the below values with the helm chart: 
        ```yaml
        awsRegion: us-east-1
        autoDiscovery:
          clusterName: <CLUSTER_NAME>
        cloudConfigPath: config/cloud.conf
        extraVolumes:
          - name: cloud-config
            configMap:
              name: cloud-config
        extraVolumeMounts:
          - name: cloud-config
            mountPath: config
        ```
* Kasten K10 (disabled by default, but internal images are pre-fetched)
    * The deployment assumes the EBS CSI addon is already installed (otherwise k10 will fail to load)
    * The snapshotting ability is enabled OOTB (using the default `ebs-vsc` VolumeSnapshotClass)
    * The export profile is not set OOTB - you will need to configure it in case you want to export the backups outside of zCompute
    * Keep in mind that k10 is only free up to 5 worker nodes - please consult Kasten's [pricing](https://www.kasten.io/pricing) for anything above that
    * For self-installation, add the repo and install the chart (no special configurations required):
         ```shell
         helm repo add kasten https://charts.kasten.io/
         helm install --create-namespace k10 kasten/k10 --namespace=kasten-io
         ```

## Optional: Make your own EKS-D image (Packer)
Only relevant if you wish to bake your own EKS-D image

* Requires importing the Ubuntu 22.04 image from the Marketplace to be used as the base image for EKS-D
* Requires a temporary use of the bastion VM (or any other VM on the public subnet) - you will need to use the bastion's private key
* Requires a local/remote environment with access to the bastion's public IP and AWS access & secret keys to zCompute
* See the packer project [documentation](eksd-packer/README.md) for more details

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
