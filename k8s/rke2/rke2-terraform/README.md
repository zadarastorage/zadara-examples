# RKE2 advanced setup


## Using Calico IPIP

* SSH into the seeder (oldest master) node via its internal IP
* Fetch the rke2.yaml in order to be able and use kubectl/calicoctl
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
