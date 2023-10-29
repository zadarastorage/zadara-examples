# Terraform
[Terraform](https://www.terraform.io/) can be used with zCompute clusters in order to automate cloud resource creation using the AWS provider for Terraform  

## Installation
Follow the [HashiCorp documentation](https://developer.hashicorp.com/terraform/downloads?product_intent=terraform)
* Zadara recommends using version 1.5 and above for optimal experience
* Due to recent changes in HashiCorp's [licensing](https://www.hashicorp.com/blog/hashicorp-adopts-business-source-license) affecting version 1.6 and above, users may consider switching to [OpenTofu](https://opentofu.org/) - apart from the installation process the only thing that will change is the actual command name (`tofu` instead of `terraform`)

## AWS Provider
* zCompute currently support the AWS Provider [version 3.33](https://registry.terraform.io/providers/hashicorp/aws/3.33.0/docs)
* Provider endpoints should refer to the zCompute cluster's API endpoints
    * When running from outside of the cluster you must use the external (public) API endpoint which is the cluster's base URL
    * When running from inside of the cluster you may also use the internal API endpoint which you can evaluate using the below command from any VM (requires jq): \
      `curl http://169.254.169.254/openstack/latest/meta_data.json | jq -c '.cluster_url' | cut -d\" -f2`
* Make sure to get your AWS credentials as mentioned on the [AWS CLI](./../aws-cli/README.md)

## Basic example
The below code snippet will create a Terraform project (folder & `main.tf` file) configured to work againts a specific zCompute (`cloud.zadara.com` in this example) and invoke the terraform CLI with given credentials parameters (AAA/BBB in this example). Once invoked it will authenticate with zCompute and create a VPC with CIDR per the provider's [documentation](https://registry.terraform.io/providers/hashicorp/aws/3.33.0/docs/resources/vpc):
```shell
mkdir tf-basic-example
cd ./tf-basic-example
cat <<EOF | tee main.tf
terraform {
  required_providers {
    aws = {
      version = "~> 3.33.0"
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  endpoints {
    ec2      = "https://cloud.zadara.com/api/v2/aws/ec2"
    sts      = "https://cloud.zadara.com/api/v2/aws/sts"
  }
  region     = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

variable "access_key" {
  type       = string
  sensitive  = true
}

variable "secret_key" {
  type       = string
  sensitive  = true
}

resource "aws_vpc" "eksd_vpc" {
  cidr_block = "10.11.12.0/24"
}
EOF
terraform init
terraform apply -auto-approve -var access_key=AAA -var secret_key=BBB
```
