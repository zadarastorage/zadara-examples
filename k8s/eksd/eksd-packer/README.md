# Zadara-baked images for EKS-D
The Zadara `eksd-packer` project can be used by any customer to bake various [EKS-D releases](https://github.com/aws/eks-distro/blob/main/README.md#releases) and manipulate them as needed. 

## Importing a pre-backed image Zadara cloud
Below is a list of pre-baked images ready for download from Zadara's public NGOS (S3 equivalent) to any Zadara cloud (Images --> Create Image --> Create image from URL).

### Kubernetes 1-27

| Release | EKS-D | Kubernetes Version | Zadara Image |
| -- | --- | --- |
| 9 | [v1-27-eks-9](https://distro.eks.amazonaws.com/kubernetes-1-27/kubernetes-1-27-eks-9.yaml) | [v1.27.4](https://github.com/kubernetes/kubernetes/release/tag/v1.27.4) | [eksd-ubuntu-1691311496_1-27-9.qcow2](https://vsa-00000029-public-il-interoplab-01.zadarazios.com/v1/AUTH_c30037d11ae04ddc870ff416bde88609/zadara-public/k8s-images/eksd-beta/eksd-ubuntu-1691311496_1-27-9.qcow2) |
| 8 | [v1-27-eks-8](https://distro.eks.amazonaws.com/kubernetes-1-27/kubernetes-1-27-eks-8.yaml) | [v1.27.3](https://github.com/kubernetes/kubernetes/release/tag/v1.27.3) | [eksd-ubuntu-1690746505_1-27-8.qcow2](https://vsa-00000029-public-il-interoplab-01.zadarazios.com/v1/AUTH_c30037d11ae04ddc870ff416bde88609/zadara-public/k8s-images/eksd-beta/eksd-ubuntu-1690746505_1-27-8.qcow2) |

## Baking an image within Zadara cloud
Inside the `eksd-packer` folder you will find an [HashiCorp Packer](https://www.packer.io/) project which will allow you to build the EKS-D image directly on the zCompute system, using the bastion VM. 
 
* On a local environment, set the below environment variables by utilizing the access & secret key you already created as part of Step #1:
  `export AWS_ACCESS_KEY_ID={access_key}`
  `export AWS_SECRET_ACCESS_KEY={secret_key}`
  `export AWS_DEFAULT_REGION=symphony`

* Copy or rename `.auto.pkrvars.template.hcl` to `.auto.pkrvars.hcl` and provide all required variables inside it.
  The following parameters should be provided:
   * `api_endpoint` - IP address or hostname of the zCompute API
   * `ssh_bastion_username` - the bastion user
   * `bastion_public_ip` - the bastion public IP
   * `ami_id` - AMI ID of a valid and accessible Ubuntu 22.04 machine image in zCompute's images
   * `ssh_username` - ssh username for the image
   * `subnet_id` - Subnet ID to provision the builder in (public subnet)
   * `ssh_keypair_name` - Keypair name to use for the builder
   * `private_keypair_path` - local path to the SSH private key (will be used by packer script to login in to the bastion and builder instances)

* You may also specify the relevant EKS-D version & revision of your choice (otherwise the default ones will be used) as stated in the [EKS-D releases](https://github.com/aws/eks-distro/blob/main/README.md#releases):
    * `eksd_k8s_version` - for example, "1-27"
    * `eksd_revision` - for example, "9"

* Run the packer command using: 
  ```shell
  packer init .
  packer build .
  ```
