# zCompute Bastion

Bastion hosts are nodes used as jumphosts to access a secure space, in our case this is used to access Kubernetes nodes that do not have a direct ingress path.   
The bastion node does not provide any cluster-essential services, has almost nothing installed and can even be stopped when not in use.   
At most, it should only have SSH present and enabled.

The Kubernetes cluster deployed by [zcompute-k8s](https://registry.terraform.io/modules/zadarastorage/k8s/zcompute/latest) allows `k3s` to internally create the necessary `kubectl` configuration, and does NOT expose any Kubernetes API's publicly. This makes a bastion node necessary to either run `kubectl`/`helm` commands directly on a control node or necessary to acquire the `kubeconfig` file for remote use(with further customization).

> [!WARNING]
> A bastion is only effective when it is configured appropriately. This means configuring the `key_pair` in the example prior to deplyoment.
> Adding a `key_pair` after initial deployment will require replacing VMs, Terraform will replace the bastion VM automatically, but the Kubernetes nodes will need to be manually "stopped" and replaced to adopt the new `key_pair` configuration.

## Connecting to a control node via the bastion

Since the node is used as a jumphost, we primarily need it's Public IP and the internal IP of a desired node.

1. Login to the zCompute Web Console
2. Switch to the desired Project from the top-right of the web page
3. Navigate to **Compute > Instances**
4. Look for the instance named `<cluster-name>-bastion` and select it
   * This will also be the only instance with an `Elastic IP` defined
5. Note down this Elastic IP, we will use it later as `BASTION_PUBLIC_IP`
6. Look for any instance named `<cluster-name>-control-<number>` and select it
7. Note down the IP for this VM, we will use it later as `CONTROL_NODE_IP`

For ease, you can SSH into a Control Node through the Bastion VM with the following command
```
PEM_KEY_PATH=#Path-to-keypair-file
BASTION_PUBLIC_IP=#Elastic-ip-of-bastion
CONTROL_NODE_IP=#Internal-ip-of-control-node
ssh -oProxyCommand="ssh ubuntu@${BASTION_PUBLIC_IP} -i ${PEM_KEY_PATH} -W %h:%p" \
    -i ${PEM_KEY_PATH} ubuntu@${CONTROL_NODE_IP}
```

If you used your default identity file for the `key_pair`, this can be simplified to
```
BASTION_PUBLIC_IP=#Elastic-ip-of-bastion
CONTROL_NODE_IP=#Internal-ip-of-control-node
ssh -J ubuntu@${BASTION_PUBLIC_IP} ubuntu@${CONTROL_NODE_IP}
```

The `kubeconfig` file is created with limited permissions, so it will be necessary to become `root` to run `kubectl` or `helm` commands:
```
sudo -i
```

## Accessing Services via the bastion

> [!INFO]
> This section primarily applies to `zcompute-k8s_gpu-preload_argo-onyx` and the supplemental applications it deploys.

ArgoCD and Grafana (backed by Victoria Metrics) are provided as samples of further applications or workflows that can be utilized here.
Further configuration should be considered for these as well(such as company-integrated auth) when evaluating for potential production deployments.

If `k8s_ingress_rootdomain` was defined, then `<your-tld-domain>` needs to be configured one of the following ways:
* Modify your computer's hosts file to set `onyx.<your-tld-domain>`, `argocd.<your-tld-domain>`, and `grafana.<your-tld-domain>` to the Traefik Loadbalancer IP.
* Set `*.<your-tld-domain>` to the Traefik Loadbalancer IP with your DNS provider.
* Set these somewhere else in your DNS chain(Company firewall/router/DNS Server/etc)

Both ArgoCD and Grafana will create a random administrator password and store it within a Kubernetes `Secret`, which we'll use the bastion VM to obtain.   

### Onyx

Onyx is configured by default with standard authentication, so the first user to create an account will be set as the admin.

If `k8s_ingress_rootdomain` was defined, then it is configured to `onyx.<your-tld-domain>` and will only answer to that domain.   
If `k8s_ingress_rootdomain` was left empty, then it was configured as a "catch-all" in the Traefik Loadbalancer. So it can be accessed via `https://<public-ip>` gained above.   

### ArgoCD

ArgoCD creates a random administrator password and stores it in a Kubernetes `Secret`.

The ArgoCD Administrator password can be obtain with:
```
PEM_KEY_PATH=<>
BASTION_PUBLIC_IP=<>
CONTROL_NODE_IP=<>
ssh -t -oProxyCommand="ssh ubuntu@${BASTION_PUBLIC_IP} -i ${PEM_KEY_PATH} -W %h:%p" \
    -i ${PEM_KEY_PATH} ubuntu@${CONTROL_NODE_IP} \
    'sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d ; echo'
```

If `k8s_ingress_rootdomain` was defined, then it is configured to `argocd.<your-tld-domain>` and will only answer to that domain(or via the port-forward method).   
If `k8s_ingress_rootdomain` was left empty, then ArgoCD is configured to remain "internal" and port-forwarding via the bastion is necessary.

To setup temporary access to ArgoCD through portforwarding through the bastion:
```
PEM_KEY_PATH=<>
BASTION_PUBLIC_IP=<>
CONTROL_NODE_IP=<>
ssh -t -oProxyCommand="ssh ubuntu@${BASTION_PUBLIC_IP} -i ${PEM_KEY_PATH} -W %h:%p" \
    -i ${PEM_KEY_PATH} ubuntu@${CONTROL_NODE_IP} \
    -L 8080:127.0.0.1:8080 \
    'watch -d sudo kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:80 --address 0.0.0.0'
```
Then open in a local browser at `http://localhost:8080`, logging in with username `admin` and the password gained from the above section.

### Grafana

Grafana creates a random administrator password and stores it in a Kubernetes `Secret`.

The Grafana Administrator password can be obtain with:
```
PEM_KEY_PATH=<>
BASTION_PUBLIC_IP=<>
CONTROL_NODE_IP=<>
ssh -t -oProxyCommand="ssh ubuntu@${BASTION_PUBLIC_IP} -i ${PEM_KEY_PATH} -W %h:%p" \
    -i ${PEM_KEY_PATH} ubuntu@${CONTROL_NODE_IP} \
    'sudo kubectl -n victoria-metrics-k8s-stack get secret victoria-metrics-k8s-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo'
```

If `k8s_ingress_rootdomain` was defined, then it is configured to `grafana.<your-tld-domain>` and will only answer to that domain(or via the port-forward method).   
If `k8s_ingress_rootdomain` was left empty, then Grafana is configured to remain "internal" and port-forwarding via the bastion is necessary.

To setup temporary access to Grafana through portforwarding through the bastion:
```
PEM_KEY_PATH=<>
BASTION_PUBLIC_IP=<>
CONTROL_NODE_IP=<>
ssh -t -oProxyCommand="ssh ubuntu@${BASTION_PUBLIC_IP} -i ${PEM_KEY_PATH} -W %h:%p" \
    -i ${PEM_KEY_PATH} ubuntu@${CONTROL_NODE_IP} \
    -L 8080:127.0.0.1:8080 \
    'watch -d sudo kubectl port-forward svc/victoria-metrics-k8s-stack-grafana -n victoria-metrics-k8s-stack 8080:80 --address 0.0.0.0'
```
Then open in a local browser at `http://localhost:8080`, logging in with username `admin` and the password gained from the above section.


