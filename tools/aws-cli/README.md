# AWS CLI
The [AWS CLI](https://aws.amazon.com/cli/) can be used with zCompute clusters by modifying the default services endpoints URLs 

## Installation
Follow the [AWS documentation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## Basic Configuration
Set your AWS credentials
* On the zCompute console - on the main Services portal under "My Profile And Security" select "Access Keys" (note the keys are per-project) and create your keys
* Use the `aws configure` command to set the access & secret keys, or use some other AWS CLI [alternatives](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) (files, environment variables etc.)

Set the zCompute services endpoint/s:
* On the zCompute console top-right corner, click on the question mark and select "API Endpoints" - these endpoints will replace the default ones which are embedded in the AWS CLI utility
    * When running CLI commands from outside of the zCompute cluster you must use the above mentioned endpoints as only they are exposed
    * When running CLI commands from inside of the zCompute cluster (any VM) you may replace the endpoint's base URL with the result of the below command (requires jq): \
      `curl http://169.254.169.254/openstack/latest/meta_data.json | jq -c '.cluster_url' | cut -d\" -f2`
* For a basic usage check, you can use the CLI-level endpoint-url override (note the region is required but not validated): \
`aws ec2 --region abc --endpoint-url https://def.zadara.com/api/v2/aws/ec2/ describe-instances`

## Configuration file
You can also use AWS CLI [profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) to define the default region and even endpoints, for example assuming you created a `default` profile in your credentials file you can add the below to the configuration file:
```yaml
[profile default]
region = abc
services = zadara

[services zadara]
ec2 = 
    endpoint_url = https://def.zadara.com/api/v2/aws/ec2/
elb = 
    endpoint_url = https://def.zadara.com/api/v2/aws/elbv2/
asg =
    endpoint_url = https://def.zadara.com/api/v2/aws/autoscaling/
iam =
    endpoint_url = https://def.zadara.com/api/v2/aws/iam/
```
Once configured, you will be able to run supported AWS CLI commands without specifying the endpoint URLs for these services: \
`aws ec2 describe-instances`

## Configuration script
For multiple AWS/zCompute environments use-cases, it may be easier to dynamically configuration by sourcing the [set-aws.sh](/set-aws.sh) script, which configures [environment variables](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html#envvars-list) that will effect the AWS CLI
* Save the script and make sure you can invoke it (consider putting it in your PATH)
* The script expects either one argument (the zCompute API endpoint) or none (for restoring normal CLI usage)
* Run the script via `source` rather than direct invocation in order for the export commands inside to affect your current session, for example: \
  `source ./set-aws.sh https://def.zadara.com`
* Once the script has set the endpoints you can run the AWS CLI commands as usual (no need to state the region): \
  `aws ec2 describe-instances`
