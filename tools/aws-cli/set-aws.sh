#!/bin/bash
#
# AWS CLI services endpoints configuration via environment variables
# Usage for setting endpoints: source ./set-aws.sh <zCompute API endpoint>
# Usage for unsetting endpoints (regular CLI usage): source ./set-aws.sh
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then 
    echo "Error: direct script invocation (so env vars will not apply) - use source instead, for example: source $0 <zCompute API endpoint>"
    exit 1
fi

if [ $# -eq 0 ]
then
  echo "Unsetting all endpoints for regular AWS CLI usage"
  unset AWS_EC2_METADATA_DISABLED
  unset AWS_DEFAULT_REGION
  unset AWS_ENDPOINT_URL_EC2
  unset AWS_ENDPOINT_URL_ELB
  unset AWS_ENDPOINT_URL_IAM
  unset AWS_ENDPOINT_URL_SNS
  unset AWS_ENDPOINT_URL_STS
  unset AWS_ENDPOINT_URL_ACM
  unset AWS_ENDPOINT_URL_AUTO_SCALING
  unset AWS_ENDPOINT_URL_CLOUDWATCH
  unset AWS_ENDPOINT_URL_ROUTE53
else
  echo "Setting all endpoints for $1"
  export AWS_EC2_METADATA_DISABLED=true
  export AWS_DEFAULT_REGION=us-east-1
  export AWS_ENDPOINT_URL_EC2=$1/api/v2/aws/ec2/
  export AWS_ENDPOINT_URL_ELB=$1/api/v2/aws/elbv2/
  export AWS_ENDPOINT_URL_IAM=$1/api/v2/aws/iam/
  export AWS_ENDPOINT_URL_SNS=$1/api/v2/aws/sns/
  export AWS_ENDPOINT_URL_STS=$1/api/v2/aws/sts/
  export AWS_ENDPOINT_URL_ACM=$1/api/v2/aws/acm/
  export AWS_ENDPOINT_URL_AUTO_SCALING=$1/api/v2/aws/autoscaling/
  export AWS_ENDPOINT_URL_CLOUDWATCH=$1/api/v2/aws/cloudwatch/
  export AWS_ENDPOINT_URL_ROUTE53=$1/api/v2/aws/route53/
fi
