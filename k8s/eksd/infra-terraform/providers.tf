terraform {
  required_providers {
    aws = {
      version = "~> 3.33.0"
      source  = "hashicorp/aws"
    }
  }
  backend "local" {}
}

provider "aws" {
  endpoints {
    ec2         = "https://${var.api_endpoint}/api/v2/aws/ec2"
    autoscaling = "https://${var.api_endpoint}/api/v2/aws/autoscaling"
    elb         = "https://${var.api_endpoint}/api/v2/aws/elbv2"
    #    elbv2   = "https://${var.api_endpoint}/api/v2/aws/elbv2"
    s3      = "https://${var.api_endpoint}:1061/"
    rds     = "https://${var.api_endpoint}/api/v2/aws/rds"
    iam     = "https://${var.api_endpoint}/api/v2/aws/iam"
    route53 = "https://${var.api_endpoint}/api/v2/aws/route53"
    sts     = "https://${var.api_endpoint}/api/v2/aws/sts"
  }

  region   = "us-east-1"
  insecure = "true"

  access_key = var.cluster_access_key
  secret_key = var.cluster_access_secret_id

  default_tags {
    tags = {
      Environment = var.environment
    }
  }
}
