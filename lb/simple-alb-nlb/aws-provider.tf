provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  # shared_credentials = var.credentials_file 
  version = "=3.0.0"
  endpoints {
    elb = "https://${var.zCompute_ip}/api/v2/aws/elbv2"
    ec2 = "https://${var.zCompute_ip}/api/v2/aws/ec2"
  }

  insecure                    = true
  skip_metadata_api_check     = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true

  # No importance for this value currently
  region = "us-east-2"
}

