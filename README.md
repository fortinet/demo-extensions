# FortiDemo Inspector
## Description
  A Terraform script to demonstrate AWS Inspector with FortiGate.

## Requirements
* [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html) 0.12
* An [AWS access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey)
* FortiOS 6.4.4
* Environment with **expect** tool support https://core.tcl-lang.org/expect/index


## Deployment overview
Terraform deploys the following components:
   - A VPC with two subnets, one private, one public
   - An Internet gateway
   - A NAT gateway
   - An Ubuntu instance in the private subnet
   - A FortiGate PAYG instance with two NICs, one in each subnet
   - An S3 bucket, to store the config files
   - A security group with no restrictions
   - An AWS Inspector template and targets

## Deployment
> **Note:** By default the script expects an ssh key at ~/.ssh/id_rsa.pub

> **Note:IPV6** The FortiGate cloud-init data expects an ipv4 address to be added to the trusthost. If you are using ipv6 you will need to adjust the trusthost under config_script set ipv4-trusthost to set ipv6-trusthost
To deploy the FortiDemo Inspector:

  1. Clone the repository.
  2. Change to the cloned directory and initialize the providers and modules:

     ```sh
     $ cd fortidemo-inspector
     $ terraform init
     ```

  3. Submit the Terraform plan using the command below. Replace the variables with your own AccessKey and Secret Key.

     ```sh
     $ terraform plan -var "access_key=<access_key>" -var "secret_key=<secret_key>" -var "fortidemo_ip=<ip_address>"
     ```

  4. Verify output.
  5. Confirm and apply the plan:

     ```sh
     $ terraform apply -var "access_key=<access_key>" -var "secret_key=<secret_key>" -var "fortidemo_ip=<ip_address>"
     ```

  6. If output is satisfactory, type `yes`.

## Destroy the cluster
To destroy the cluster, use the command:

```sh
$ terraform destroy -var "access_key=<access_key>" -var "secret_key=<secret_key>"
```

## Additional information
The region is hard-coded to `us-west-1`. If the region is changed, the inspector rules must also be changed under `rules_package_arns` in ` "aws_inspector_assessment_template" "inspector_template"`.
Inspector rule ARNs can be found [here](https://docs.aws.amazon.com/inspector/latest/userguide/inspector_rules-arns.html).

# Support
Fortinet-provided scripts in this and other GitHub projects do not fall under the regular Fortinet technical support scope and are not supported by FortiCare Support Services.
For direct issues, please refer to the [Issues](https://github.com/fortinet/demo-extensions/issues) tab of this GitHub project.
For other questions related to this project, contact [github@fortinet.com](mailto:github@fortinet.com).

## License
[License](https://github.com/fortinet/demo-extensions/blob/master/LICENSE) © Fortinet Technologies. All rights reserved.
