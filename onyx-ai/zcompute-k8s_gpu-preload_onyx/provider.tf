variable "zcompute_endpoint_url" {
  type        = string
  description = "IP/DNS of zCompute Region API Endpoint. ex: https://compute-us-west-101.zadara.com"
}

variable "zcompute_access_key" {
  type        = string
  description = "Amazon style zCompute access key"
}

variable "zcompute_secret_key" {
  type        = string
  sensitive   = true
  description = "Amazon style zCompute secret key"
}

provider "aws" {
  endpoints {
    ec2         = "${var.zcompute_endpoint_url}/api/v2/aws/ec2"
    autoscaling = "${var.zcompute_endpoint_url}/api/v2/aws/autoscaling"
    elb         = "${var.zcompute_endpoint_url}/api/v2/aws/elbv2"
    #elbv2      = "${var.zcompute_endpoint_url}/api/v2/aws/elbv2"
    s3      = "${var.zcompute_endpoint_url}:1061/"
    rds     = "${var.zcompute_endpoint_url}/api/v2/aws/rds"
    iam     = "${var.zcompute_endpoint_url}/api/v2/aws/iam"
    route53 = "${var.zcompute_endpoint_url}/api/v2/aws/route53"
    sts     = "${var.zcompute_endpoint_url}/api/v2/aws/sts"
  }

  region   = "us-east-1"
  insecure = "true"

  access_key = var.zcompute_access_key
  secret_key = var.zcompute_secret_key
}
