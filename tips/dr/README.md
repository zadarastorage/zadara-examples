# How to restore EKS-D after control-plane disaster

## The problem
In case of a control-plane disaster (for example losing 2 master nodes out of 3) you may need to force ETCD to reset the master node leadership, and in some cases you may even need restore the ETCD datastore from an earlier backup.

Zadara's EKS-D solution includes a built-in periodical ETCD backup procedure within each master node in the control-plane, including local & remote backups as mentioned [here](../../k8s/eksd/README.md#optional-post-deployment-dr-configuration).

The ETCD restore procedure is quite simple however it differs for various use-cases as mentioned below. 

## Use-case alternatives
1. Restore the ETCD quorom (assuming at least one running master node which was presiously operational)
2. Restore the ETCD database (assuming no running master nodes which were presiously operational)

## Example for alternative #1 (restoring ETCD quorom)
1. SSH to a relevant master node through the bastion VM (you will need the master's key-pair private file)
2. Make sure this node has a local backup file at `/etc/kubernetes/zadara/etcd_*.db` (if it doesn't this master was never operational and you need to find another one or use alternative #2)
3. Copy the local backup file to the bastion VM (just in order to keep it safe)
4. Detach this master node from the masters ASG
5. Scale the masters ASG to 0
6. Add this master node to the NLB's target group
7. Re-run the ETCD static pod with the `--force-new-cluster` flag (remove the manifest from `/etc/kubernetes/manifests/etcd.yaml`, edit it and move it back in)
8. Once the cluster is responsive (try kubectl within 2-3 minutes), re-run the ETCD status pod without the `--force-new-cluster` flag (remove the manifest from `/etc/kubernetes/manifests/etcd.yaml`, edit it and move it back in)
9. Set the masters ASG to your normal highly-available capacity
10. Once all the new masters ASG-based VMs have joined the cluster, delete the old master node VM

## Example for alternative #2 (restoring ETCD database)
1. Set the masters ASG to a single node (min=max=desired=1)
2. Once a single master node is ready SSH into it through the bastion VM (you will need the master's key-pair private file)
3. Copy the relevant file from either one of these remote backups:
   * Using zCompute console, create a volume from an earlier control-plane snapshot (the default convension is `EKS-D_autosnap_<vm>` with a `managed_by` tag containing the cluster name) and attach it to the current master node - once mounted the file should be within the drive's original location (`/<drive>/etc/kubernetes/zadara/etcd_*.db`) so you can copy it and later detach & delete the volume
   * Assuming you enabled exporting the backup to Object Storage (NGOS/S3) location, copy the file directly from the target bucket into the current master node - the default convension is `<bucket>/<cluster>/<vm>/<timestamp_host>` (you can use the AWS CLI which is already installed on the master node for the list/copy operation) 
6. Delete (if exist) the current ETCD folder with `rm -rf /var/lib/etcd/member` 
7. Restore the ETCD database from the backup file with `etcdutl snapshot restore <filename> --data-dir /var/lib/etcd`
8. Re-run the ETCD static pod with the `--force-new-cluster` flag (remove the manifest from `/etc/kubernetes/manifests/etcd.yaml`, edit it and move it back in)
9. Once the cluster is responsive (try kubectl within 2-3 minutes), Re-run the ETCD status pod without the `--force-new-cluster` flag (remove the manifest from `/etc/kubernetes/manifests/etcd.yaml`, edit it and move it back in)
10. Set the masters ASG to your normal highly-available capacity (min=max=desired) and wait for Kubernetes to show all master nodes in ready state
