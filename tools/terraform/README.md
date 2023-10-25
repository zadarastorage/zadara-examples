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
The below code snippet will configure Terraform to work againts a given zCompute cluster with given credentials and create a VPC per the provider's [documentation](https://registry.terraform.io/providers/hashicorp/aws/3.33.0/docs/resources/vpc):
```shell
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
    ec2      = "https://${var.api_endpoint}/api/v2/aws/ec2"
    sts      = "https://${var.api_endpoint}/api/v2/aws/sts"
  }
  region     = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

variable "api_endpoint" {
  type       = string
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
```

Once initialized (with `terraform init`), such a project can be applied via the below command or other alternatives per the terraform [documentation](https://developer.hashicorp.com/terraform/cli/commands/apply): \
`terraform apply -auto-approve -var api_endpoint=cloud.zadara.com -var access_key=abc123 -var secret_key=321cba`
