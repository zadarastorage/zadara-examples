# Terraform Project - Onyx AI in Kubernetes on zCompute - Minimal

This project is to quickly setup Onyx AI within your zCompute account.

It is assumed that the user already knows their zCompute site's URL, and has configured the relevant **Access Keys** and **VM Placement Rules**. If not, please review [Preparing zCompute Account](01_setup-zcompute.md).

It is also necessary to provide S3-Compatible Object Storage credentials to the convenience script so that the cluster's backup and auto-restore functionality is enabled.

> [!WARNING]
> Warning: This version of the guide deploys resources in a minimal configuration, which does not ensure high availability. However K8s will try to recover interrupted services automatically with some downtime.

## Default Resource requirements

The project is deployed with some limits primarily intended to offer a buffer for upgrades/maintenance/etc for things within Kubernetes, and should be adequate for continued operation.

The minimum represents a "stable" and "idle" deployment, and the maxmimum represents the configured limits within the Terraform Project.   
This range is intended to provide a buffer for scaling up/down from regular usage, software updates or other user changes.

| Resource | Min | Max |
| -------- | --- | --- |
| Instances  | 14 | 18 |
| Elastic IPs | 4 | 4 |
| vCPU | 40 | 88 |
| RAM | 241G | 625G |
| vGPU (Tesla L4) | 1 | 3 |
| EBS Storage | ~774G | TBD |

> [!WARNING]
> It is important to ensure that the zCompute account has adequate account limits to run this project.

## Getting started

The overall process can take ~15 minutes to deploy and stabilize, so here is the process and more details about what it's doing is available for further reading.

This procedure assumes Mac or Linux, and deploys the `zcompute-k8s_gpu-preload_onyx` Terraform project. Windows may be used, but `Windows Subsystem for Linux` is recommended.

### Deployment

This example primarily installs a Kubernetes cluster with Ollama and Onyx preinstalled, with Onyx configured as a catch-all endpoint in the loadbalancer.

### Launch the project

1. Clone this repository
   * ```
     git clone --depth 1 -b main https://github.com/zadarastorage/zadara-examples.git
     ```
2. Move into the onyx-ai directory
   * ```
     cd zadara-examples/onyx-ai
     ```
3. Launch the `configure.sh` convienence script
   * ```
     ./configure.sh zcompute-k8s_gpu-preload_onyx
     ```
   * Answer all the questions, if you make a mistake, you can edit the results later in `zcompute-k8s_gpu-preload_onyx/config.auto.tfvars`
4. Potential extra modifications to k8s.tf
   * Some zCompute clouds are in process of an instance type renewal for GPU VMs, or will be in the near future.
   * `ZGL4.7large` Is set as default which replaces `GPU_L4.7large`, you may need to revise this in [k8s.tf](https://github.com/zadarastorage/zadara-examples/blob/main/onyx-ai/zcompute-k8s_gpu-preload_onyx/k8s.tf#L336) depending on the zCompute version
5. Launch the `deploy.sh` convienence script
   * ```
     ./deploy.sh zcompute-k8s_gpu-preload_onyx
     ```
   * Script will initialize any Terraform dependencies and eventually ask the user to approve the deployment by entering `yes`
6. Launch the `deploy.sh` convienence script a second time
   * ```
     ./deploy.sh zcompute-k8s_gpu-preload_onyx
     ```
   * This is to validate all resources/tags were deployed, it will prompt again for `yes` if any changes are necessary.
7. Steps 4 and 5 will have launched all the essentials via Terraform, from there the Kubernetes cluster will initialize itself and finish deploying/configuring things like a public loadbalancer

> [!CAUTION]
> These scripts will maintain your `config.auto.tfvars` and other state-related files within the same folder as the project launched. Take care manipulating or deleting them as that can cause Terraform to be out-of-sync.

### Obtain the Traefik Loadbalancer IP

By default, the project deploys the latest available Ubuntu VMs, installs [k3s](https://k3s.io/) and some resources preconfigured for zCompute.   
This includes [Traefik](https://traefik.io/) as a default Ingress controller, which will trigger a zCompute Loadbalancer to be created when the cluster is stable.

1. Login to the zCompute Web Console
2. Switch to the desired Project from the top-right of the web page
3. Navigate to **Load Balancing > Load Balancers**
4. There should be 2 Load balancers(Or will be soon)
   * `*traefik-*` - Created by the AWS Load Balancer Controller within k3s upon detection of the Traefik Ingress controller (automatic)
   * `<cluster-name>-kapi` - Was created by Terraform to provide HA access for internal k3s APIs to all cluster members, this should be left alone
5. The **Public IP** of the entry with the word `traefik` in it is the loadbalancer for your deployment.

From here, access can be gained to the Onyx software via `https://<public-ip>`. By default a self-signed certificate will be used for demonstration purposes.

### (Optional) Using the bastion node to gain access to control nodes

[zCompute K8s Bastion](zcompute_bastion.md)

## Destroying the cluster

If you need to tear down the cluster, run:
```
./cleanup.sh k8s_gpu-preload_onyx
```

You need to enter “**yes**” to confirm.

On first try it will fail due to resources created by the Kubernetes cluster and not Terraform, they should be deleted manually from the zCompute Web Console before trying again. They're located at:

* **Load Balancing > Load Balancers**
  * There should be 1 Load Balancer to remove
* **Load Balancing > Target Groups**
  * There should be 2 Target Groups to remove here
* **VPC Networking > Security Groups**
  * There should be 2 Security Groups where the description contains `[k8s]`
* **Storage > Block Storage**
  * There should be at least 4 Volumes here in `Not Attached` state, and the names should all begin with `pvc-`
  * This is optional, and does not block VPC destruction.

### Onyx Application

[Configuring Onyx](onyx_configure.md)   
[Interacting with Onyx](onyx_usage.md)

## Infrastructure overview

[Infrastructure Overview - zCompute](onyx_infrastructure-zcompute.md)   
[Infrastructure Overview - Kubernetes](onyx_infrastructure-kubernetes.md)

## Production Cluster Considerations

[Production Considerations](production-considerations.md)
