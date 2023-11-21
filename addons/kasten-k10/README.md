# Kasten K10
[K10](https://docs.kasten.io/latest/index.html) enables various backup & restore use-cases for Kubernetes clusters & applications - it runs natively on Zadara [EKS-D](/k8s/eksd/README.md), either as a built-in addon or via manual installation as described below

## Notes
* The deployment assumes the EBS CSI addon is already installed (otherwise k10 will fail to load)
* The deployment will not define an export profile - you will need to configure it post-deployment in case you want to export backups outside of zCompute
* The deployment will enable public-facing dashboard access via NLB - for more information about dashboard access please refer to the [K10 manual](https://docs.kasten.io/latest/access/dashboard.html)
* The deployment will enable basic authentication using the `htpasswd` chart value to create a default username `kasten` and password `Zadara!2023` - as mentioned in Kasten's [documentation](https://docs.kasten.io/latest/access/authentication.html#basic-auth) you are advised to change these default credentials via binary or online [tool](http://www.htaccesstools.com/htpasswd-generator/)
* Keep in mind that K10 is only free up to 5 worker nodes - please consult Kasten's [pricing](https://www.kasten.io/pricing) for anything above that

## Installation example
* Ensure Helm is installed and the kubectl context is correctly pointing to the relevant Kubernetes cluster
* Run the below code snippet to create the values file and run the Helm installation:
  ```shell
  helm repo add kasten https://charts.kasten.io/
  helm repo update
  cat <<EOF | tee values.yaml
  externalGateway:
    create: true
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
  auth:
    basicAuth:
      enabled: true
      htpasswd: 'kasten:{SHA}7NMrp20iv1w7D2GbHA9kTOq4DV0='
  EOF
  helm install --create-namespace k10 kasten/k10 --namespace=kasten-io --values values.yaml
  ```

Once installed, check the zCompute console for the NLB public IP and access the dashboard via http://{public-ip}/k10/#