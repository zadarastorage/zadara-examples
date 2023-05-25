
# Overview - Elastic Load Balancer
This terraform will create two webservers from a given ami, and instantiate a load balancer to actively balance them.
To get the AMI id, simply fetch the image AWS id from the zCompute UI (`ami-<uuid without dashes>`). 

>This example's load balancer is configured as external, you can modify it to internal by modifying the lb-web.tf file

## zCompute Pre-requisite Check list
1. Ensure you have enabled and initialized load balancer service
2. Ensure you have imported an Ubuntu cloud image and make this image public, grab the AMI ID and insert it into your .tfvars file
3. Ensure your tenants project that you are deploying into had access keys generated (insert the access/secret keys into your .tfvars file)

## Getting started
1. Make sure you have the required terraform version installed
2. Modify the `terraform.tfvars` file according to your environment
3. Run `terraform init`
4. Run `terraform apply`
5. After the solution is deployed, you should be able to go to the IP of your load balancer and refresh, each time it should redirect you to the other web server which is displaying it's instance ID so you know you're on a different server. 
