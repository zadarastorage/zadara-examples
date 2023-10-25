# AWS EBS CSI Driver
[EBS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html) enables the creation & attachment of EBS volumes & snapshots via AWS API integration with the EC2 service

## Notes
* The `ebs-cs` StorageClass will be configured with the VolumeType and set as the default StorageClass (you may [override](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/) it with other CSIs)
* The snapshotting abilities will be configured with the `ebs-vsc` VolumeSnapshotClass (including the Kasten-ready [annotation](https://docs.kasten.io/latest/install/storage.html#csi-snapshot-configuration) for seamless operability)

## Installation example
* Ensure Helm is installed and the kubectl context is correctly pointing to the relevant Kubernetes cluster
* The below `EBS_ALIAS` should refer to the zCompute VolumeType
  * Usually the default VolumeType will be `gp2` but that may change based on your zCompute cluster settings and/or preferences
  * For a list of available VolumeType alternatives consult with your cloud admin or run the below Symp command: \
    `volume volume-types list -c name -c alias -c operational_state -c health -m grep=ProvisioningEnabled`
  * Note the value must be one of: io1 / io2 / gp2 / gp3 / sc1 / st1 / standard / sbp1 / sbg1
* Run the below code snippet to create the values file and run the Helm installation:
  ```shell
  kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
  kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
  kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
  kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/groupsnapshot.storage.k8s.io_volumegroupsnapshotclasses.yaml
  kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/groupsnapshot.storage.k8s.io_volumegroupsnapshotcontents.yaml
  kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/groupsnapshot.storage.k8s.io_volumegroupsnapshots.yaml
  kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
  kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
  helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
  helm repo update
  cat <<EOF | tee values.yaml
  controller:
    region: 'us-east-1'
  sidecars:
    provisioner:
      additionalArgs:
        - --timeout=60s
        - --retry-interval-start=4s
    attacher:
      additionalArgs: 
        - --timeout=60s
        - --retry-interval-start=4s
  storageClasses:
    - name: ebs-sc
      annotations:
        storageclass.kubernetes.io/is-default-class: "true"
      parameters:
        type: <EBS_ALIAS>
  volumeSnapshotClasses: 
    - name: ebs-vsc
      annotations:
        snapshot.storage.kubernetes.io/is-default-class: "true"
        k10.kasten.io/is-snapshot-class: "true"
      deletionPolicy: Delete
  EOF
  helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver --namespace=kube-system --values values.yaml
  ```