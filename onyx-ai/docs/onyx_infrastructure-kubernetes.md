# Infrastructure Overview - Kubernetes

## Helm Charts

[Helm](https://helm.sh) is a kind of package manager for Kubernetes, capable of accepting configuration variables to deploy complex applications.

### Provided by zcompute-k8s Terraform Module

The [zcompute-k8s](https://registry.terraform.io/modules/zadarastorage/k8s/zcompute/latest) Terraform Module automatically installs and configures essential Helm charts for Kubernetes features like load balancers and dynamic volume allocation.

* [zadara-aws-config](https://github.com/zadarastorage/helm-charts/tree/main/charts/zadara-aws-config)
  * Provides common ConfigMap files for use by various AWS-compatible Kubernetes Operators, preconfigured for most zCompute deployments
* [aws-cloud-controller-manager](https://github.com/kubernetes/cloud-provider-aws)
  * Uses AWS APIs to interact with zCompute to assist with proper lifecycling of Kubernetes nodes
* [flannel](https://github.com/flannel-io/flannel)
  * One of many popular CNI plugins to handle inter-node networking
* [aws-ebs-csi-driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
  * Provides dynamic RWO volume management using AWS APIs with zCompute
* [cluster-autoscaler](https://github.com/kubernetes/autoscaler)
  * Monitors Kubernetes cluster resources and zCompute Autoscaling groups to identify when more or less resources may be required
* [aws-load-balancer-controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller)
  * Provides the Kubernetes cluster with `Loadbalancer` support by managing zCompute Loadbalancers on-demand
* Traefik
  * A popular `Ingress` Controller that is provided by `k3s` by default, our deployment has already be customized to ensure a `Loadbalancer` resource is created for this

### Extra included included in all examples

* [gpu-operator](https://github.com/NVIDIA/gpu-operator)
  * Operator provided by NVIDIA to properly tag all GPU-enabled Kubernetes nodes
  * Optionally can be used to install drivers on compatible Kubernetes nodes, but this is specific to the node's operating system
* [cert-manager](https://github.com/cert-manager/cert-manager)
  * Manages TLS/SSL certificate lifecycles within the cluster, for example managing LetsEncrypt certificates
* [cloudnative-pg](https://github.com/cloudnative-pg/cloudnative-pg)
  * Operator that handles the full lifecycle and HA of PostreSQL clusters through the Kuberentes cluster

### Provided in `zcompute-k8s_gpu-preload_onyx` example

* [ollama](https://github.com/ollama/ollama) via [ollama-helm](https://github.com/otwld/ollama-helm)
  * Open-source utility for managing and running large language models locally
* [onyx](https://onyx.app) via Zadara's [onyx](https://github.com/zadarastorage/helm-charts/tree/main/charts/onyx) chart
  * An AI assistant that integrates with your organization's tools and documents to provide real-time, context-aware answers

### Provided in `zcompute-k8s_gpu-preload_argo-onyx` example

* [argocd](https://github.com/argoproj/argo-cd)
  * Declarative Continuous Deployment system
* argo-examples-operators
  * App-of-Apps bundle package that manages the `gpu-operator`, `cert-manager` and `cloudnative-pg` operators
* argo-examples-onyx
  * App-of-Apps bundle package that manages the `ollama` and `onyx` packages

## Onyx

The Onyx application requires:
* Redis
* PostgreSQL
* Vespa AI

The helm chart developed by Zadara focuses on providing highly redundant resources. Minor modifications to Onyx are required to enable redundant storage of embeddings within a multi-node Vespa deployment.
