# EKS-D automated deployment
Below is an example (not OOTB production-grade solution, read more about it in the full [documentation](./docs/README.md)) for an EKS-D automated deployment on zCompute - facilitating cloud integration with dynamic ASG scaling, instance labeling & lifecycle, native load balancing, built-in storage capabilities and optional Kasten K10 as a backup & restore solution. 

## Known limitations
* zCompute minimal version is **23.08** running in VSC-mode
* Upgraded zCompute clouds must have at least one AWS-compatible VolumeType API Alias (io1 / io2 / gp2 / gp3 / sc1 / st1 / standard / sbp1 / sbg1) to be available for provisioning (fresh 23.08 installations have them OOTB)
* The EKS-D cluster name (set by the `environment` variable as mentioned below) must be unique across the account, and not used in other projects in the same account 
* In this version, by default, the masters will be created directly using terraform `aws_instance` entities instead of AutoScalingGroup
This is due to the cloud AutoScalingGroup control inability to detect the masters **K8S level health** and its tendency to replace master
instances before the new instances are part of the cluster and the ETCD quorum.
  * Changes and migration process from previous ASG based configuration are explained [here](#changes-and-migration-from-asg-based-configuration)
* **:warning:** When the `manage_masters_using_asg` flag is set to `true` and the Cluster Autoscaler is used to create the master instances, it might also scale-down the control-plane ASG which may affect the ETCD quorum and even brick the cluster, so make sure to use min=max=desired for the masters ASG capacity (default is 1=1=1)
* The Cluster Autoscaler might also scale-down the control-plane ASG which may affect the ETCD quorom and even brick the cluster, so make sure to use min=max=desired for the masters ASG capacity (default is 1=1=1)
* This version add a rudimentary support for using different directories for terraform state files and output using the terraform `local` backend.
However, it is recommended to replace the `local` backend with a production-grade backends like s3.
Use the `--state-path` flag with the `apply-all.sh` and `destory-all.sh` scripts to specify the state directory. If not provided
the system will use the local directory.
* Deletion and recreation of the same plan in a short duration may fail due to asynchronous resource deletion and name collisions. Wait at least 10 minutes between consecutive invocations.
## Remote backend configuration
* The deployment comes with local backend by default which isn't recommended for production-grade clusters.
* The `apply-all.sh` and `destroy-all.sh` scripts can support local or remote backend, once a backend.tf file has been detected within `infra-terraform` or `eksd-terraform` remote backend will be initalized instead of the default local one.
*  in order to configure remote backend add a backend.tf (must be named backend.tf) config file to `infra-terraform` & `eksd-terraform` folders respectively, before the first time your run the apply-all.sh script. <br>
`backend.tf.example` :
```
terraform {
    backend "s3" {
      bucket = "dev-bucket"
      key    = "tfstate/infra/terraform.tfstate"
      region = "us-east-1"
    }
}
```
* the deployment creates two state files, one for infra and the other for eksd, therefore it is recommended to create two seperare folders within the remote location, e.g.  `tfstate/infra/terraform.tfstate` & `tfstate/eksd/terraform.tfstate` and point the backend keys to the respective path.

* **:warning:** if remote backend is configured always make sure both `infra-terraform` & `eksd-terraform` contain a backend.tf file, otherwise you might end up in a split brain scenario where you have a local backend for the infra and a remote backend for eksd or vice versa.
## Security concerns
* The pre-baked EKS-D image modifies the default Ubuntu [udev service](https://manpages.ubuntu.com/manpages/jammy/man7/udev.7.html) sandboxing permissions by allowing API calls to be made upon new volume attachment (required for the EBS CSI operation)

* **:warning:** This version uses a new `zadara_disk_mapper.py` script that will not use the API calls if the device-name is encoded in the disk serial. 
This is expected to be a breaking change in the next zCompute upgrade, so it recommended to push the updated script to all existing workers, or upgrade them to the new image
available in zCompute **23.08.4** service pack. This script is both forward and backward compatible with the old version of EKS-D

* The deployment will create and use a bastion VM with port 22 (SSH) exposed to the world (and EKS-D nodes with port 22 exposed to the bastion) - you may want to limit this exposure, stop or even terminate the bastion VM post-deployment
* The deployment will create a public-facing NLB for the control-plane api-server, exposing Kubernetes to the world - you may want to limit this exposure to private networks per the documentation below

## Changes and migration from ASG based configuration
### Changes from previous script version
This script support both the new standalone master nodes and the old ASG based configurations.
  * By default, the script will create a standalone master nodes
  * In order to use the previous ASG implementation set `manage_masters_using_asg` to `true`
  * In the standalone configuration the names of the master nodes were changed to `environment`-master-sa-N to denote their standalone nature
  * The initial cluster leader is now always the first VM
  * In order to change the number of master instances change the `masters_count` variable and re-run the 2nd phase terraform using the `--eksd-only` flag.
  * For convenience the ASG can be kept, and can be used as a template for creation of new master nodes instances via the UI.
It is important to detach the created instances from it after the join the cluster.

### Migration from ASG based configuration
In order to migrate from a previous configuration using the ASG, follow the next procedure:
* Make sure the terraform flag `manage_masters_using_asg` is set to false
* Rerun the `apply-all.sh` using the `--eksd-only` flag
* The script will try to detect if there is an existing AutoScalingGroup in the environment.
* If there's an existing ASG, the script it will not delete or change its status
* The script will add new master instance/s, and add them to a new target-group
* These new standalone instances will automatically join the cluster as control-nodes
* **:bell:** the `get_kubeconfig.sh` may not be able to extract the `kubeconfig` file after migration. However, this is not needed as the file is not changed between runs, and the script operation can be safely interrupted
* After the new master nodes join the cluster and reach `ready` status, manually change the load-balancer configuration to use the newly created target-group
* After the cluster is reachable using the new target-group and the new master nodes, follow the next steps to remove the old ASG controlled nodes
  * Make sure all new node are available in K8S
  * Make sure all new nodes ETCd pods are available and ready. Login into one of the new master nodes and run:
     * `etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key -w table member list`
     * `etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key -w table endpoint status --cluster`
  * Note: All the nodes should appear in the table, one of the nodes should be the leader
  * Transfers ETCd leadership to one of the new servers. From the designated leader run:
     * `etcdctl --endpoints=127.0.0.1:2379,<current-leader-endpoint> --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key move-leader <designated-leader-id>`
* For each ASG control node follow the next procedure:
  1. Drain the ASG master node
  2. Delete the ASG master node
  3. Remove the ASG master node. From one of the new master nodes run:
     * `etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key member remove <nodeid-to-remove>`
  4. Detach the ASG master node, while decreasing the number of instances in the ASG.
  5. Delete of the ASG master node VM
* Repeat the steps 1-5 until all ASG managed nodes are deleted
* The ASG can be kept and its launch configuration is modified to allow quick creation of new master nodes from the API/UI.
* If you decide to delete the ASG, consecutive runs of the script will detect this and run accordingly.
* If new instance are created using the ASG, it is recommended to detach the created instances from the ASG and import them into the terraform as standalone instances using terraform import state functionality.

## zCompute prerequisites
* Storage:
    * Verify your provisioning-enabled VolumeType aliases - usually this would be `gp2` but you can validate it by asking your cloud admin or running the below Symp command via the Zadara toolbox VM using your zCompute account (domain) and credentials: \
    `volume volume-types list -c name -c alias -c is_provisioning_disabled -c is_default -c state -c health -m grep=Normal` \
    The EBS CSI will use 'gp2' as the default VolumeType unless specified otherwise via the terraform `ebs_csi_volume_type` variable in the eksd-terraform project
* Images:
    * Ubuntu 22.04 image should be imported from the Marketplace to be used for the Bastion VM
    * Zadara's pre-baked EKS-D image should be imported from the Marketplace to be used for the Kubernetes nodes
* Credentials:
    * Key-pair for the bastion server (either import or create a new one)
    * Key-Pair for the master servers (can be the same)
    * Key-Pair for the worker agents (can be the same)
    * AWS programmatic credentials (access key & secret key) with tenant-admin, AWS MemberFullAccess & IAMFullAccess permissions for the relevant project
    * In this version, for better security, AWS credentials are not passed on the command line any more but are expected to be pass as environment variables 

## All-In-One approach
For a simplified/demo experience, you can use this option to streamline a cluster deployment with a single command - you will get the OOTB default values of a small-sized cluster with a basic CNI (Flannel) and all addons except for Kasten K10. Note this option should not be used for production-grade deployments (for example the default control-plane is not HA), however you may change the default values as mentioned below to use this approach for any cluster configuration. 

* This version support two options for creating the master nodes.
    * AutoScalingGroup - The legacy mode - not recommended for production use due the ASG controller stateless mode, and lack of an application level health check in this template.
    * Direct Instances - Controlling creation of control node using re-execution of the terraform script. 
In order to facilitate this, you need to change the number of `masters_count` and rerun the `apply-all.sh` with the `--eksd-only` flag.
Multiple executions of the script are allowed will simply re-run the terraform apply command.     
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
    * IMPORTANT - for production use-cases, Zadara recommends revising all non-default properties mentioned in the sections below - for example setting 3 master nodes (using `masters_count`) for control-plane high-availability, setting the external backup properties (like `backup_bucket`) for control-plane [DR capabilities](../../tips/dr/README.md), etc.
* Run `AWS_ACCESS_KEY_ID=<> AWS_SECRET_ACCESS_KEY=<> apply-all.sh [--state-path <state files directory>]` with your access_key & secret_key as the parameters (or set the AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY environment variables before running the script without specifying parameters)
    * The script will take about 10 minutes for a successful minimal deployment of a single master & worker
    * The script can be rerun for re-applying Terraform changes (for example as part of an upgrade procedure)
    * If necessary, you can destroy all assets and reset everything with the `destroy-all.sh [--state-path <state files directory>]` script (with the same two credentials parameters/variables)
    * If the `--state-path` parameter is not provided the local directory is used 
* Once completed you will see the kubeconfig content ready for your usage (presented on screen and as a kubeconfig file in the running directory) so you can skip the next two phased approach steps and use it as-is ;-) 

## Phased approach step 1 - Infrastructure deployment
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
    * Default Security Group for the VPC as well as EKS-D-related & bastion-only dedicated ones
    * Bastion VM on the public subnet (**accessible to the world by default**) with access to the private subnet (where the Kubernetes nodes will be located)
    * Network Load Balancer to hold the Kubernetes API Server endpoints - accessible to the world by default, can be hardened for internal-only access if you add the variable `expose_k8s_api_publicly = false`
    * Elastic IPs for the Bastion as well as the Network Load Balancer
* `terraform apply --auto-approve` - this will make the actual changes on the environment
* Due to current zCompute limitation, you will need to re-apply Terraform again in order to populate some resource tags (resource names, etc.)
* Terraform will output the relevant information required for the next step - if you lose track of them you can always run `terraform output` to list them again
* In the next step you will also be required to provide the NLB's private & public IPs - you can get those from the GUI or by running the `get_loadbalancer.sh` script as proposed in the terraform output message
* Note that the subnets' MTU must match the edge network MTU - if there's a mismatch you should adjust both private & public subnets MTUs accordingly via zCompute GUI before continuing

## Phased approach step 2 - EKS-D deployment
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
        * `manage_masters_using_asg` - use the Cluster AutoScaler to manage the master nodes (default is false, true is currently not recommended for production) 
        * `workers_count` - the amount of worker nodes (minimal is 0, defaulting to 1 + 3 more for max ASG size of 4)
        * `masters_instance_type` - the masters VM size (minimal is z2.large, defaulting to z4.large)
        * `masters_instance_type` - the workers VM size (minimal is z2.large, defaulting to z8.large)
        * `masters_volume_size` - the masters disk size (minimal is 30GB, defaulting to 50GB)
        * `workers_volume_size` - the workers disk size (minimal is 30GB, defaulting to 100GB)
        * `cni_provider` - choose the CNI from a list of flannel (default), calico or cilium (experimental)
        * `ebs_csi_volume_type` - the cloud's storage VolumeType (defaulting to gp2)
        * `install_ebs_csi` - whether to deploy the EBS CSI driver addon (defaulting to true)
        * `install_lb_controller` - whether to deploy the AWS Load Balancer Controller addon (defaulting to true)
        * `install_autoscaler` - whether to deploy the Cluster Autoscaler addon (defaulting to true)
        * `install_kasten_k10` - whether to deploy the Kasten K10 addon (defaulting to false)
        * `backup_access_key_id` - external NGOS/S3 user access-key for ETCD backup export
        * `backup_secret_access_key` - external NGOS/S3 user secret-key for ETCD backup export
        * `backup_region` - external NGOS/S3 region for ETCD backup export (defaulting to us-east-1)
        * `backup_endpoint` - external NGOS endpoint for ETCD backup export (not needed for AWS S3)
        * `backup_bucket` - external NGOS/S3 bucket name for ETCD backup export
        * `backup_rotation` - maximal number of backups to retain (defaulting to 100, setting to 0 will disable all backups)
* `terraform init` - this will initialize Terraform for the environment
* `terraform plan` - this will output the changes that Terraform will actually do (resource creation), for example:
    * EKS-D master nodes ASG + Launch Configuration
    * Load Balancer target group for the master nodes ASG + publish listener on 6443 for the API server
    * EKS-D worker nodes ASGs + Launch Configuration
    * Tag the existing private & public subnets for Load Balancer controller discovery
* `terraform apply` - this will make the actual changes on the environment

Once Terraform is over, you will need to get the kubeconfig file from the first master node - you can use the `get_kubeconfig.sh` script as mentioned on the `terraform output` in order to fetch the initial kubeconfig from the first master node (through the bastion) into the project's directory.

Use the kubeconfig to connect to the Kubernetes cluster in the usual way - congratulations on your new cluster :) 

## OOTB content
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

## Optional addons
As mentioned, your cluster can come pre-deployed with the latest versions (at the time of EKS-D image baking) of the below addons. Alternatively, you may change/delete them via helm after the deployment, or choose to install them by yourself:

* EBS CSI driver (enabled by default):
    * The `ebs-cs` StorageClass is pre-configured with the VolumeType and set as the default StorageClass (you may [override](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/) it with other CSIs)
    * The snapshotting abilities are pre-configured with the `ebs-vsc` VolumeSnapshotClass (including the Kasten-ready [annotation](https://docs.kasten.io/latest/install/storage.html#csi-snapshot-configuration) for seamless operability)
    * For self-installation, use the dedicated [instructions](../../addons/aws-ebs-csi-driver/README.md)
* AWS Load Balancer Controller (enabled by default)
    * For NLB - use the LoadBalancer service per the [documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/annotations)
      * The latest controller version overrides the built-in LoadBalancer resource, so you just need to add the `service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing` annotation for internet-facing NLB (as the default is internal)
      * As a [known limitation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/service/nlb/#security-group), the controller wouldn't create the relevant security group to the NLB - rather, it will add the relevant rules to the worker node's security group and you can attach this (or another) security group to the NLB via the zCompute GUI, AWS CLI or Symp
    * For ALB - use the Ingress resource per the [documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/ingress/annotations)
      * By default, all Ingress resources are [internal-facing](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/ingress/annotations/#scheme) - if you want your ALB to get a public IP you will have to add the `alb.ingress.kubernetes.io/scheme: internet-facing` annotation
    * For self-installation, use the dedicated [instructions](../../addons/aws-load-balancer-controller/README.md) 
* Cluster Autoscaler (enabled by default)
    * The configuration is pre-populated to use the [auto-discovery mode](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#auto-discovery-setup) based on the pre-populated tags on the worker ASG (`k8s.io/cluster-autoscaler/enabled` and `k8s.io/cluster-autoscaler/<cluster-name>`) where cluster-name is the environment variable set on the eksd-terraform project
    * If you opt to use the [manual mode](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#manual-configuration)  - remember to define the specific workers ASG/s name/s and their lower/upper bounds on the [autoscalingGroups](https://github.com/kubernetes/autoscaler/blob/master/charts/cluster-autoscaler/values.yaml#L39) values
    * For self-installation, use the dedicated [instructions](../../addons/cluster-autoscaler/README.md)
* Kasten K10 (disabled by default, but internal images are pre-fetched)
    * The deployment assumes the EBS CSI addon is already installed (otherwise k10 will fail to load)
    * The snapshotting ability is enabled OOTB (using the default `ebs-vsc` VolumeSnapshotClass)
    * The export profile is not set OOTB - you will need to configure it in case you want to export the backups outside of zCompute
    * Keep in mind that k10 is only free up to 5 worker nodes - please consult Kasten's [pricing](https://www.kasten.io/pricing) for anything above that
    * For self-installation, use the dedicated [instructions](../../addons/kasten-k10/README.md)

## Optional post-deployment DR configuration
Unless configured as part of the eksd-terraform variables, the EKS-D cluster's internal ETCD datastore automated backup procedure (running every 2 hours) will save the latest backup locally within each master node, as well as take a snapshot of the whole boot drive and save it inside the zCompute cloud. 

In addition, users may configure the Kubernetes secret below in order to dynamically enable/disable backup exports to NGOS/S3 in order to enhance the cluster's [DR capabilities](../../tips/dr/README.md) in case of a control-plane meltdown:
```shell
kubectl create secret generic zadara-backup-export \
    --namespace kube-system \
    --from-literal=backup_access_key_id="<access key>" \
    --from-literal=backup_secret_access_key="<secret key>" \
    --from-literal=backup_region="<bucket region>" \
    --from-literal=backup_endpoint="<NGOS endpoint full URL (not relevant for S3)>" \
    --from-literal=backup_bucket="<bucket name>"
```
Once set, the periodical ETCD backup procedure within each master node will also export the latest backup into the relevant NGOS/S3 location. 

Please note such configuration will override the pre-defined terraform variables-based exteral backup configuration. 

## Optional post deployment upgrade of the EKSD K8S version
### Proposed upgrade procedure when master nodes managed by Terraform instances
In order to use `terraform` for continuous management of the EKSD master nodes you will need to
use terraform `backend` functionality. It is recommended to change the setup to use a production grade backend and not the
`local` backend provided here for reference.
For 3 node master nodes the procedure flow should be similar to:
* Replace the AMI ID in the `terraform.tfvars` file in the backend location
* Increase the number of desired master nodes by 1, and re-apply the terraform script
* The terraform script should create a new additional master node using the updated AMI
* Wait for the newly created master node to join the cluster and make sure it is healthy
* Cordon the first master node and drain it
* Make sure the new node ETCd pods are available and ready. Login into one the new master node and run:
     * `etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key -w table member list`
     * `etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key -w table endpoint status --cluster`
  * Note: All the nodes should appear in the table, one of the nodes should be the leader
  * Transfers ETCd leadership to the new server. From the node run:
     * `etcdctl --endpoints=127.0.0.1:2379,<current-leader-endpoint> --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key move-leader <designated-leader-id>`
* When possible delete the first master node.
* Re-apply the terraform script, it should recreate the first master node using the updated AMI
* Repeat the steps above until all master nodes are replaced with the new version.
* Cordon the first new master node created and drain it
* Make sure the new node ETCd pods are available and ready. Login into one the other new master nodes and run:
     * `etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key -w table member list`
     * `etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key -w table endpoint status --cluster`
  * Note: All the nodes should appear in the table, one of the nodes should be the leader
  * Transfers ETCd leadership to one of the new server. From the node run:
     * `etcdctl --endpoints=127.0.0.1:2379,<current-leader-endpoint> --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key move-leader <designated-leader-id>`
* Decrease the number of desired master nodes by 1, and re-apply the terraform script
* The terraform script should delete the additional node.
* Make sure the new node ETCd pods are available and ready.

### Proposed upgrade procedure for workers nodes managed by ASG
For workers nodes the procedure flow should be similar to:
* Create a new launch configuration using the updated AMI and increase the number of desired workers nodes by 1
  * this can be done from the UI or by updating the `terraform.tfvars` file and re-applying the terraform script
* The ASG should create a new additional worker node using the updated AMI
* Wait for the newly created node to join the cluster and make sure it is healthy
* Cordon and drain the first node and when all pods migrated out of it delete it
* The ASG should create a new additional worker node using the updated AMI
* Wait for the newly created node to join the cluster and make sure it is healthy
* repeat the process until all worker nodes are upgraded
* Decrease the number of desired master nodes by 1
  * this can be done from the UI or by updating the `terraform.tfvars` file and re-applying the terraform script

## Optional BYOI (create your own EKS-D image with Packer)
Only relevant if you wish to bake your own EKS-D image

* Requires importing the Ubuntu 22.04 image from the Marketplace to be used as the base image for EKS-D
* Requires a temporary use of the bastion VM (or any other VM on the public subnet) - you will need to use the bastion's private key
* Requires a local/remote environment with access to the bastion's public IP and AWS access & secret keys to zCompute
* See the packer project [documentation](eksd-packer/README.md) for more details

## Optional Zadara CSI usage
Only relevant if you wish to utilize the Zadara CSI and use a dedicated VPSA to persist data from your Kubernetes

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
