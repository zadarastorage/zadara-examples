# How to restore EKS-D from an ETCD backup

## The problem
In case of a control-plane disaster (for example losing 2 master nodes out of 3) you may need to force ETCD to reset the master node leadership, and in some cases you may even need restore the ETCD datastore from an earlier backup.

Zadara's EKS-D solution includes a built-in periodical ETCD backup procedure within each master node, and potentially also exporting these backups to an external NGOS/S3 location. 

The restore procedure is quite simple however it differs for various use-cases as mentioned below. 

## The alternatives
1. Restore the ETCD quorom (assuming at least one running master node which was presiously operational)
2. Restore ETCD database (assuming no running master nodes which were presiously operational)

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
3. Copy the latest backup file from the remote NGOS/S3 (you can use the built-in AWS CLI for that)
4. Delete (if exist) the current ETCD folder with `rm -rf /var/lib/etcd/member` 
5. Restore the ETCD database from the backup file with `etcdutl snapshot restore <filename> --data-dir /var/lib/etcd`
6. Re-run the ETCD static pod with the `--force-new-cluster` flag (remove the manifest from `/etc/kubernetes/manifests/etcd.yaml`, edit it and move it back in)
7. Once the cluster is responsive (try kubectl within 2-3 minutes), Re-run the ETCD status pod without the `--force-new-cluster` flag (remove the manifest from `/etc/kubernetes/manifests/etcd.yaml`, edit it and move it back in)
8. Set the masters ASG to your normal highly-available capacity (min=max=desired) and wait for Kubernetes to show all master nodes in ready state
