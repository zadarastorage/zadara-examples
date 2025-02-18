# Terraform Project - Onyx AI in Kubernetes on zCompute - High Availability

This project is to quickly setup Onyx AI within your zCompute account.

It is assumed that the user already knows their zCompute site's URL, and has configured the relevant **Access Keys** and **VM Placement Rules**. If not, please review [Preparing zCompute Account](01_setup-zcompute.md).

## Default Resource requirements

The project is deployed with some limits primarily intended to offer a buffer for upgrades/maintenance/etc for things within Kubernetes, and should be adequate for continued operation.

The minimum represents a "stable" and "idle" deployment, and the maxmimum represents the configured limits within the Terraform Project.   
This range is intended to provide a buffer for scaling up/down from regular usage, software updates or other user changes.

| Resource | Min | Max |
| -------- | --- | --- |
| Instances  | 16 | 18 |
| Elastic IPs | 4 | 4 |
| vCPU | 75 | 88 |
| RAM | 529G | 625G |
| vGPU (Tesla A16) | 2 | 3 |
| EBS Storage | ~1120GB | TBD |

> [!WARNING]
> It is important to ensure that the zCompute account has adequate account limits to run this project.

## Getting started

The overall process can take ~15 minutes to deploy and stabilize, so here is the process and more details about what it's doing is available for further reading.

This procedure assumes Mac or Linux, and deploys the `zcompute-k8s_gpu-preload_argo-onyx` Terraform project. Windows may be used, but `Windows Subsystem for Linux` is recommended.

### Deployment

This example installs Ollama and Onyx, but also includes ArgoCD for CI/CD and Victoria Metrics with Grafana, and is designed for 2 usage methods.

A specific variable when running the `configure.sh` script in the next section controls this deplyment behavior.

1. `k8s_ingress_rootdomain` set to `<your-tld-domain>`
   * Example: `domain.xyz`
   * Onyx is configured to `onyx.<your-tld-domain>`
   * ArgoCD is configured to `argocd.<your-tld-domain>`
   * Grafana is configured to `grafana.<your-tld-domain>`
2. `k8s_ingress_rootdomain` left empty
   * Onyx is configured as "catch-all" just like the non-Argo/Non-HA example
   * ArgoCD and Grafana may be reached via port-forward through the bastion VM

A self-signed TLS certificate will still be used regardless of choice, and both cases still require connecting to the cluster through the bastion to obtain the admin passwords for ArgoCD and Grafana.

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
     ./configure.sh zcompute-k8s_gpu-preload_argo-onyx
     ```
   * Answer all the questions, if you make a mistake, you can edit the results later in `zcompute-k8s_gpu-preload_argo-onyx/config.auto.tfvars`
4. Launch the `deploy.sh` convienence script
   * ```
     ./deploy.sh zcompute-k8s_gpu-preload_argo-onyx
     ```
   * Script will initialize any Terraform dependencies and eventually ask the user to approve the deployment by entering `yes`
5. Launch the `deploy.sh` convienence script a second time
   * ```
     ./deploy.sh zcompute-k8s_gpu-preload_argo-onyx
     ```
   * This is to validate all resources/tags were deployed, it will prompt again for `yes` if any changes are necessary.
6. Steps 4 and 5 will have launched all the essentials via Terraform, from there the Kubernetes cluster will initialize itself and finish deploying/configuring things like a public loadbalancer

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

### Using the Bastion node to interact with Kuberentes directly

ArgoCD and Grafana create a random Administrator password by default, and store them in a Kubernetes `Secret`.   
Instructions to obtain this or generally access the Kubernetes API directly can be found in the following doc on how to use the Bastion.

[zCompute K8s Bastion](zcompute_bastion.md)

If you are primarily interested in interacting with Onyx, then you can either access it via `https://<traefik-public-ip>` gained from above or `https://onyx.<your-tld-domain>` if you provided a rootdomain during configuration, then move on to [Onyx Application](#onyx-application)

## Destroying the cluster

If you need to tear down the cluster, run:
```
./cleanup.sh k8s_gpu-preload_argo-onyx
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
