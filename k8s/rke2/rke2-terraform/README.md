# RKE2 Multi-Cluster setup


## Prerequisites: Primary & Secondary clusters

* Primary & Secondary zCompute clusters VPC configuration - you will need to provide Terraform with both cluster’s relevant resource ids:
    * Public/Private subnet should exist (for the load balancer)
    * Private subnet should be configured with Direct Subnet connectivity between clusters
    * Security group should enable all internal traffic (using the group) as well as all traffic to/from the Direct Subnet’s range and the VPSA
    * Routing to VPSA (if not on the same direct subnet range)

* RKE2 AMI (1.23.4) on both clusters - you will need to provide Terraform with both cluster’s AMI AWS ids
* Key-Pair for the master servers - you will need to provide Terraform with the name
* Key-Pair for the worker agents (can be the same one as the master one) on both primary & secondary clusters - you will need to provide Terraform with the name/s
* AWS programmatic credentials (access key & secret id) for the primary & secondary cluster - you will need to provide Terraform with the access key & secret id
* SSH access to Primary cluster VMs using some bastion VM on the public subnet with security group to access the Seeder node and potentially other Kubernetes nodes (can be the same group)
* VPSA with 1 pool and programmatic credentials (access key) - you will need to provide the access key to the Zadara CSI Storage Class configuration

## Step 1: Load Balancer

* Create NLB on the primary cluster's relevant subnet & security group - make sure it has high-availability
* You will need to provide Terraform with the below NLB information:
    * LB id
    * Private IP
    * Public IP
    * Internal DNS

## Step 2: Terraform

* Terraform init
* Terraform plan
* Terraform apply
    * RKE2 Seeder (single-node ASG for the first cluster node) in the primary cluster
    * RKE2 master nodes ASG in primary clusters
    * Load Balancer target group for the master nodes ASG + public listener on 6443 for the API server
    * RKE2 worker nodes ASGs in both primary & secondary clusters
    * Tag the existing private & public subnets for Load Balancer controller discovery

## Step 3: Calico IPIP

* Get the Seeder internal IP
* Fetch the kube.conf in order to be able and use kubectl/calicoctl
* Switch Calico from the default VXLAN to IPIP:
  * After the installation of the RKE2 seeder node we need to apply the following config \
    <code>kubectl apply -f rke2-calico-config.yaml</code>
    ```yaml
      apiVersion: helm.cattle.io/v1
      kind: HelmChartConfig
      metadata:
       name: rke2-calico
       namespace: kube-system
      spec:
       valuesContent: |-
         installation:
           calicoNetwork:
             bgp: Enabled
             ipPools:
             - blockSize: 24
               cidr: ${ calico_cidr }
               encapsulation: IPIP
               natOutgoing: Enabled
    ```
  * use kubectl to apply the BGP configuration <strong><em>kubectl apply -f bgpconfiguration.yaml</em></strong>
    ```yaml
    apiVersion: crd.projectcalico.org/v1
    kind: BGPConfiguration
    metadata:
     name: default
    spec:
     asNumber: 64512
     listenPort: 179
     logSeverityScreen: Info
     nodeToNodeMeshEnabled: true
    ```
  * Edit the default IP Pool resource (<strong><em>kubectl edit ippools default-ipv4-ippool</em></strong>) and make sure that <strong><em>vxlanMode</em></strong> is set to <strong><em>Never</em></strong> and <strong><em>ipipMode</em></strong> is set to <strong><em>Always</em></strong>
    ```yaml
    apiVersion: crd.projectcalico.org/v1
    kind: IPPool
    metadata:
     name: default-ipv4-ippool
    spec:
     allowedUses:
     - Workload
     - Tunnel
     blockSize: 24
     cidr: 10.42.0.0/16
     ipipMode: Always
     natOutgoing: true
     nodeSelector: all()
     vxlanMode: Never
    ```
  * Edit the FelixConfiguration resource (<strong><em>kubectl edit FelixConfiguration default</em></strong>) and make sure that <strong><em>ipipEnabled</em></strong> is set to <strong><em>true</em></strong> and <strong><em>vxlanEnabled</em></strong> is <strong>not</strong> present. 
    ```yaml
    apiVersion: crd.projectcalico.org/v1
    kind: FelixConfiguration
    metadata:
     annotations:
       meta.helm.sh/release-name: rke2-calico
       meta.helm.sh/release-namespace: kube-system
     labels:
       app.kubernetes.io/managed-by: Helm
     name: default
    spec:
     bpfLogLevel: ""
     featureDetectOverride: ChecksumOffloadBroken=true
     ipipEnabled: true
     logSeverityScreen: Info
     reportingInterval: 0s
     wireguardEnabled: false
    ```
  * After completing all the above steps, restart the DaemonSet of the calico-node: \
  <code>kubectl delete pods -l k8s-app=calico-node -n calico-system</code>

  * In order to validate that the pods are using IPIP follow these steps:
    * Run 2 pods on separate nodes.
    * Ping between those 2 pods.
    * SSH into one of the nodes and use tcpdump command against the eth0 interface: \
      <code>sudo tcpdump -vvnneSs 0 -i eth0 not port 22</code>

    See this example output: \
    15:32:41.630575 fa:16:3e:98:a9:67 > fa:16:3e:bf:b0:3c, ethertype IPv4 (0x0800), length 118: (tos 0x0, ttl 63, id 14377, offset 0, flags [none], <strong>proto IPIP (4)</strong>, length 104)
	  10.0.16.7 > 10.0.16.22: (tos 0x0, ttl 63, id 53293, offset 0, flags [none], proto ICMP (1), length 84)
	  10.42.185.7 > 10.42.0.27: ICMP echo reply, id 21, seq 151, length 64

## Step 4: Zadara Storage Class

* Deploy the Zadara CSI V2 (early access preview)
    * Clone the [zadara-csi](https://github.com/zadarastorage/zadara-csi) repository
    * Checkout the master branch and get the chart: \
      https://github.com/zadarastorage/zadara-csi/tree/master/deploy/helm/zadara-csi
    * Override the image tag value to “2.0.0-pre8” and deploy
* Note the post deployment Helm notification for the CRDs definitions:
    * Follow the Zadara CSI documentation to configure [VSC](https://github.com/zadarastorage/zadara-csi/blob/master/docs/configuring_vsc.md) (with the VPSA hostname/IP and access key) 
    * Follow the Zadara CSI documentation to configure [Storage Class](https://github.com/zadarastorage/zadara-csi/blob/master/docs/configuring_storage.md)


## Step 5: AWS Load Balancer controller

* Add the [AWS Load Balancer controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller/tree/main/helm/aws-load-balancer-controller) Helm repo: \
  <code>helm repo add eks [https://aws.github.io/eks-charts](https://aws.github.io/eks-charts)</code>
* Create value file named <code>values.yaml</code> according to the below specification (remember to update the primary cluster hostname with the zCompute URL):
  ```yaml
  clusterName:  # cluster name
  vpcId: # primary cluster's vpc id
  image:
    repository: amazon/aws-alb-ingress-controller
  awsApiEndpoints: "ec2=https://<primary_cluster_hostname>/api/v2/aws/ec2,elasticloadbalancing=https://<primary_cluster_hostname>/api/v2/aws/elbv2,acm=https://<primary_cluster_hostname>/api/v2/aws/acm,sts=https://<primary_cluster_hostname>/api/v2/aws/sts"
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
* Deploy your ingress controller (for example, nginx) and configure it with the following:
  ```yaml
  nodeSelector:
    worker-role: primary

  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: instance
      service.beta.kubernetes.io/aws-load-balancer-target-node-labels: worker-role=primary # important for multi cluster setup
      service.beta.kubernetes.io/aws-load-balancer-type: external
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
  ```
  The AWS Load Balancer Controller documentation, including specific annotations can be found here:
  * [Ingress](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations)
  * [Service](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/service/annotations)
