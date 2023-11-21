# AWS Load Balancer Controller
[Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller) (or LBC in short) enables the creation & manipulation of NLBs & ALBs via AWS API integration with the Load Balancer service

## Notes
* For NLB - use the LoadBalancer service per the [documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/annotations)
  * The latest controller version overrides the built-in LoadBalancer resource, so you just need to add the `service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing` annotation for internet-facing NLB (as the default is internal)
  * As a [known limitation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/service/nlb/#security-group), the controller wouldn't create the relevant security group to the NLB - rather, it will add the relevant rules to the worker node's security group and you can attach this (or another) security group to the NLB via the zCompute GUI, AWS CLI or Symp
* For ALB - use the Ingress resource per the [documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/ingress/annotations)
  * By default all Ingress resources are [internal-facing](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/ingress/annotations/#scheme) - if you want your ALB to get a public IP you will have to add the `alb.ingress.kubernetes.io/scheme: internet-facing` annotation

## Installation example
* Ensure Helm is installed and the kubectl context is correctly pointing to the relevant Kubernetes cluster
* The below `clusterName` value will be populated according to the kubectl context (you may change it as needed)
* The below `VPC_ID` value should refer to the relevant VPC's AWS id (you can get that from the zCompute console)
* The below `API_ENDPOINT` should refer to the zCompute cluster's API endpoint
  * You may use the zCompute cluster's base URL for this value but note it means the LBC will access the API endpoint externally (from the internet)
  * Alternatively you may use the internal API endpoint (available only from within the cluster) by running the below command from any VM: \
    `curl http://169.254.169.254/openstack/latest/meta_data.json | jq -c '.cluster_url' | cut -d\" -f2`
* Run the below code snippet to create the values file and run the Helm installation:
  ```shell
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update
  cat <<EOF | tee values.yaml
  clusterName: $(kubectl config current-context | cut -d '@' -f2)
  vpcId: <VPC_ID>
  awsApiEndpoints: "ec2=<API_ENDPOINT>/api/v2/aws/ec2,elasticloadbalancing=<API_ENDPOINT>/api/v2/aws/elbv2,acm=<API_ENDPOINT>/api/v2/aws/acm,sts=<API_ENDPOINT>/api/v2/aws/sts"
  enableShield: false
  enableWaf: false
  enableWafv2: false
  region: us-east-1
  ingressClassConfig:
    default: true
  EOF
  helm install aws-load-balancer-controller eks/aws-load-balancer-controller --namespace=kube-system --values values.yaml
  ```