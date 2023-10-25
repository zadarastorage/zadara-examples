# Cluster Autoscaler
[Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master) enables dynamic scaling of Kubernetes cluster nodes via AWS API integration with the ASG service

## Notes
* The [auto-discovery mode](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#auto-discovery-setup) is advised as it is based on the pre-populated tags on the worker ASG (`k8s.io/cluster-autoscaler/enabled` and `k8s.io/cluster-autoscaler/<cluster-name>`) where cluster-name is the environment variable set on the eksd-terraform project
* If you opt to use the [manual mode](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#manual-configuration) - remember to define the specific workers ASG/s name/s and their lower/upper bounds on the [autoscalingGroups](https://github.com/kubernetes/autoscaler/blob/master/charts/cluster-autoscaler/values.yaml#L39) values
* The below chart depends on the `cloud-config` ConfigMap which is pre-deployed in the kube-system namespace - if you will use another namespace for Cluster Autoscaler you will need to replicate it
* Always make sure to set min=max=desired capacity for the masters ASG as Cluster Autoscaler may try to scale it down (which will potencially brick the EKS-D cluster)

## Installation example
* Ensure Helm is installed and the kubectl context is correctly pointing to the relevant Kubernetes cluster
* Assuming you opt for auto-discovery, the below `clusterName` value will be populated according to the kubectl context (you may change it as needed)
* Run the below code snippet to create the values file and run the Helm installation:
  ```shell
  helm repo add autoscaler https://kubernetes.github.io/autoscaler
  helm repo update
  cat <<EOF | tee values.yaml
  awsRegion: us-east-1
  autoDiscovery:
    clusterName: $(kubectl config current-context | cut -d '@' -f2)
  cloudConfigPath: config/cloud.conf
  extraVolumes:
    - name: cloud-config
      configMap:
        name: cloud-config
  extraVolumeMounts:
    - name: cloud-config
      mountPath: config
  EOF
  helm install cluster-autoscaler autoscaler/cluster-autoscaler --namespace=kube-system --values values.yaml
  ```