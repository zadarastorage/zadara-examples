## Production Cluster Considerations

This example project runs the minimum project to stand up a stable Kubernetes cluster and provide Ollama and Onyx with minimal resources to run, as such it may not follow best practices or easily offer desired flexibility.  
Some of the known points are highlighted below.

### DNS
Without any special DNS configuration, only a single external facing Kubernetes `Ingress` can be supported, as otherwise the Traefik controller would need to know which DNS name was requested to route to a specific Ingress. In the above demo, the only externally exposed Ingress is Onyx itself.   
Others like **ArgoCD** or **Grafana** could be exposed with proper DNS support.

As Zadara does not offer a global DNS resolver service, an external service should be used.  There are two main approaches.
1. external-dns Kubernetes Service
  * If your domain can be controlled by a major DNS provider with API access, such as Cloudflare or AWS Route53 (see the `external-dns` documentation for supported providers), `external-dns` could be installed and configured to dynamically create DNS entries for your requested Ingress resources.
2. Wildcard DNS
   * Another option would be to configure a wildcard response to the Traefik load balancer external IP (e.g. the same IP entered in the browser above to access Onyx).  Using this example, you could point `*.zadara-k8s.example.com` to `a.b.c.d`, then make sure your Ingress records conform to that wildcard (e.g. `chat.zadara-k8s.example.com`).

### TLS/SSL Certificates

This example configures TLS certificates as self signed, meaning the user has to accept a browser warning to open the site.   
Due to limitations regarding http-01 LetsEncrypt challenges with zCompute load balancers, it is not currently a viable option.   
That leaves dns-01 as functional with the correct configuration for the cert-manager application that gets installed in the cluster.   
This also necessitates a supported DNS provider with API, similar to the DNS section above.

### High Availability

At the core, this example simply deploys a Kubernetes cluster and auto-installs Ollama and Onyx in a non-HA fashion.   
Should any availability event occur, Kubernetes will attempt to migrate Pods to other available Virtual Machines, however there will generally not be a secondary Pod ready to go to maintain services during that time.  
In this repsect, the cluster is fairly self-healing, but not technically highly available.

The other example [zcompute-k8s_gpu-preload_argo-onyx](zcompute-k8s_gpu-preload_argo-onyx.md) add Argo as a deployment mechanism and additionally enables Highly Available configurations where possible.

### Terraform Project Structure

This example was provided to be simple, as such both the "Infrastructure" and "Cluster" configurations are merged here.   
This is not generally recommended from a Terraform project standpoint as it increases the impact-radius of a misconfigured Terraform project. **Potentially leading to loss of services and/or data.**

"Best Practices" generally showcase this type of project as at-least 2 separate Terraform Projects:
* Infrastructure - Handles creating the VPC, Subnets, Core Security Groups and all relevant tags to ensure Kubernetes Operators can correctly identify permissable resources in the account
* Cluster - Handles the creation of Launch Configurations, Autoscaling groups, supplemental Security groups and cluster-specific load balancers.

However many components of this project may be copied/referenced to construct the above structure.

### Kubernetes - Running workloads on GPU Workers

Using this project, Cluster VMs are launched with appropriate tagging to represent their role (Control/Worker), as well as the presence of a GPU.   
The cluster nodes start up with constraints to prevent non-essential workloads from running on Control-nodes, as well as preventing non-GPU workloads from running on GPU-nodes.

Three Kubernetes configurations are necessary to enable and map a GPU workload to a GPU-node.

#### Runtime Class

