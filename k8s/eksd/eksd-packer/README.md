# Zadara-baked images for EKS-D
The Zadara `eksd-packer` project can be used by any customer to bake various [EKS-D releases](https://github.com/aws/eks-distro/blob/main/README.md#releases) and manipulate them as needed. 

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
