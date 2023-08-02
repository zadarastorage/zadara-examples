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
    ec2         = "https://${var.zcompute_api}/api/v2/aws/ec2"
    autoscaling = "https://${var.zcompute_api}/api/v2/aws/autoscaling"
    elb         = "https://${var.zcompute_api}/api/v2/aws/elbv2"
    #    elbv2   = "https://${var.zcompute_api}/api/v2/aws/elbv2"
    s3      = "https://${var.zcompute_api}:1061/"
    rds     = "https://${var.zcompute_api}/api/v2/aws/rds"
    iam     = "https://${var.zcompute_api}/api/v2/aws/iam"
    route53 = "https://${var.zcompute_api}/api/v2/aws/route53"
    sts     = "https://${var.zcompute_api}/api/v2/aws/sts"
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