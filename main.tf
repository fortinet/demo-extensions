// Configure the AWS Provider
provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region

}
terraform {
  required_providers {
    fortios = {
      source  = "fortinetdev/fortios"
      version = "1.10.4"
    }
  }
}
// Create a Template file with the proper TOKEN and Hostname attributes
// This allows us to execute the FortiOS provider after the aws_eip and token are generated
// See the following for more information:
// https://github.com/hashicorp/terraform/issues/2976
// https://github.com/hashicorp/terraform/issues/2430
//

data "template_file" "setup_fortios_provider" {
  depends_on = [null_resource.test_instance_is_up]
  template   = file("./terraform_fortios_provider/provider_prerender")
  vars = {
    aws_eip       = aws_eip.fortigate_eip.public_ip,
    token         = data.external.setup_api_key.result.token
    forti_demo_ip = var.fortidemo_ip,
    admin_pass    = var.admin_pass
  }
}
// Create the provider TF file.With the template values.
resource "local_file" "create_fortios_provider_tf_file" {
  content  = data.template_file.setup_fortios_provider.rendered
  filename = "${path.module}/terraform_fortios_provider/provider.tf"
}

data "external" "external_ip" {
  program = ["bash", "get-external-ip.sh"]
}
data "external" "setup_api_key" {
  depends_on = [local_file.setup_token]
  program    = ["bash", "./run-set-api-key.sh"]
}


data "template_file" "setup_token" {
  depends_on = [null_resource.test_instance_is_up]
  template   = file("./set-api-key.sh")
  vars = {
    fortigate_Ip = aws_eip.fortigate_eip.public_ip,
  }
}
resource "local_file" "setup_token" {
  content  = data.template_file.setup_token.rendered
  filename = "${path.module}/set-api-key.sh.rendered"
}

variable "region" {
  type    = string
  default = "us-west-1" //Default Region

}
data "aws_caller_identity" "current" {}

variable "access_key" {
  type    = string
  default = ""
}
variable "secret_key" {
  type    = string
  default = ""
}

variable "key_name" {
  type    = string
  default = "id_rsa.pub"
}
variable "public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}
resource "aws_key_pair" "keypair" {
  key_name   = "${random_string.random_name_post.result}-${var.key_name}"
  public_key = file(var.public_key_path)
}
variable "az_default" {
  type    = string
  default = "us-west-1c"
}
variable "fortidemo_ip" {
  type    = string
  default = ""
}
variable "admin_pass" {
  type    = string
  default = "SecurityFabric"
}
variable "cluster_name" {
  type    = string
  default = "fortidemo" //Must be lowercase for s3
}

//Find aws_eip and replace in config file:

//TODO:clean up unsused vars.
data "template_file" "setup-nat-eip" {
  template = file("${path.module}/config_script")
  vars = {
    aws_eip       = aws_eip.fortigate_eip.public_ip,
    forti_demo_ip = var.fortidemo_ip,
    trusted_host  = data.external.external_ip.result.ipAddress,
    admin_pass    = var.admin_pass
  }
}

resource "null_resource" "test_instance_is_up" {
  provisioner "remote-exec" {
    connection {
      host = aws_eip.fortigate_eip.public_ip
      user = "admin"
    }
  }
}
resource "null_resource" "init_fortios_provider" {
  depends_on = [local_file.create_fortios_provider_tf_file]


  provisioner "local-exec" {
    working_dir = "./terraform_fortios_provider/"
    command     = "terraform init"
  }
}
resource "null_resource" "execute_fortios_provider" {
  depends_on = [null_resource.init_fortios_provider]


  provisioner "local-exec" {
    working_dir = "./terraform_fortios_provider/"
    command     = "terraform apply -auto-approve"
  }
}

data "template_file" "setup-inspector-run" {
  template = file("./runInspector.py")
  vars = {
    template_name = aws_inspector_assessment_template.inspector_template.name,
    template_arn  = aws_inspector_assessment_template.inspector_template.arn,
    region        = var.region
  }
}
data "template_file" "cloud-init" {
  template = file("./cloud-init.sh")
  vars = {
    s3_url     = "s3://${aws_s3_bucket.s3_bucket.id}/${aws_s3_bucket_object.config_script.id}"
    region     = var.region
    private_ip = aws_network_interface.fgt_second_nic.private_ip //secondary nic IP
  }
}
resource "local_file" "runInspector_render" {
  content  = data.template_file.setup-inspector-run.rendered
  filename = "${path.module}/runInspector.py.rendered"
}
//Create a random 3 char suffix to avoid collisions
resource "random_string" "random_name_post" {
  length           = 5
  special          = true
  override_special = ""
  min_lower        = 5
}

//Rule Data for AWS inspector - Returns all rules for that region
data "aws_inspector_rules_packages" "rules" {}

// Create a VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name    = "${var.cluster_name}-VPC-Main-${random_string.random_name_post.result}"
    Account = data.aws_caller_identity.current.arn
    Type    = "FortiDemo-Terraform"
  }
}

//Create a Subnet
resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = var.az_default
  cidr_block        = "10.0.1.0/24"

  tags = {
    Name    = "${var.cluster_name}-Subnet-Main-${random_string.random_name_post.result}"
    Type    = "FortiDemo-Terraform"
    Account = data.aws_caller_identity.current.arn

  }
}

//Second Subnet for the client
resource "aws_subnet" "secondary" {
  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = var.az_default
  cidr_block        = "10.0.2.0/24"

  tags = {
    Name    = "${var.cluster_name}-Subnet-Secondary-${random_string.random_name_post.result}"
    Type    = "FortiDemo-Terraform"
    Account = data.aws_caller_identity.current.arn
  }
}

//Security Group
resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id //Attach to the VPC

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"] # Allow All ingress
  }
  egress {
    from_port        = "0"
    to_port          = "0"
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name    = "${var.cluster_name}-Sec-Group-Allow-Ingress-${random_string.random_name_post.result}"
    Account = data.aws_caller_identity.current.arn
    Type    = "FortiDemo-Terraform"
  }
}
//Define the IAM role for the ec2
//This allows the python script to run inspector
//No spaces allowed between <<EOF and first bracket
resource "aws_iam_role" "fortidemo_iam_role" {
  name               = "${var.cluster_name}-iamrole-${random_string.random_name_post.result}"
  assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
EOF
}
//IAM Policy
//Inspector Policy, additional permissions added
//so that SDN connector can get proper values
resource "aws_iam_policy" "fortidemo_policy" {
  name        = "${var.cluster_name}-policy-${random_string.random_name_post.result}"
  description = "FortiDemo Inspector Policy"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "inspector:ListEventSubscriptions",
                "inspector:ListAssessmentTargets",
                "inspector:ListAssessmentTemplates",
                "inspector:ListTagsForResource",
                "inspector:PreviewAgents",
                "inspector:DescribeRulesPackages",
                "inspector:ListAssessmentRuns",
                "inspector:StartAssessmentRun",
                "inspector:GetTelemetryMetadata",
                "inspector:DescribeAssessmentTargets",
                "inspector:ListAssessmentRunAgents",
                "inspector:DescribeResourceGroups",
                "inspector:DescribeCrossAccountAccessRole",
                "inspector:ListFindings",
                "inspector:DescribeAssessmentTemplates",
                "inspector:DescribeAssessmentRuns",
                "inspector:StopAssessmentRun",
                "inspector:ListRulesPackages",
                "inspector:DescribeFindings"
            ],
            "Resource": "*"
        }
       ]
}
EOF
}
resource "aws_iam_policy" "fortidemo_s3_policy" {
  name        = "${var.cluster_name}-s3-policy-${random_string.random_name_post.result}"
  description = "S3 Policy"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucketByTags",
                "s3:ListBucketMultipartUploads",
                "s3:DescribeJob",
                "s3:ListJobs",
                "s3:ListBucketVersions",
                "s3:Get*",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
resource "aws_iam_policy" "fortidemo_ec2_policy" {
  name        = "${var.cluster_name}-ec2-policy-${random_string.random_name_post.result}"
  description = "Ec2 SDN Policy"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ec2:Describe*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "elasticloadbalancing:Describe*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:ListMetrics",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:Describe*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "autoscaling:Describe*",
            "Resource": "*"
        }
    ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "policy_attach_ec2" {
  role       = aws_iam_role.fortidemo_iam_role.name
  policy_arn = aws_iam_policy.fortidemo_ec2_policy.arn
}
//Role attachment
resource "aws_iam_role_policy_attachment" "policy_attach" {
  role       = aws_iam_role.fortidemo_iam_role.name
  policy_arn = aws_iam_policy.fortidemo_policy.arn
}
resource "aws_iam_role_policy_attachment" "policy_attach_s3" {
  role       = aws_iam_role.fortidemo_iam_role.name
  policy_arn = aws_iam_policy.fortidemo_s3_policy.arn
}
resource "aws_iam_instance_profile" "fortidemo" {
  name = "${var.cluster_name}-instance_profile-${random_string.random_name_post.result}"
  role = aws_iam_role.fortidemo_iam_role.name
}

//Specify aws_nat_gateway
resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.fortigate_eip_nat_gateway.id
  subnet_id     = aws_subnet.main.id

  tags = {
    Name    = "${var.cluster_name}-NatGateway-${random_string.random_name_post.result}"
    Account = data.aws_caller_identity.current.arn
    Type    = "FortiDemo-Terraform"
  }
}
resource "aws_eip" "fortigate_eip_nat_gateway" {
  vpc              = true
  public_ipv4_pool = "amazon"
  tags = {
    Name    = "${var.cluster_name}-Fortigate-EIP-${random_string.random_name_post.result}"
    Account = data.aws_caller_identity.current.arn
    Type    = "FortiDemo-Terraform"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name    = "${var.cluster_name}-IGW-Main-${random_string.random_name_post.result}"
    Account = data.aws_caller_identity.current.arn
    Type    = "FortiDemo-Terraform"
  }
}


//  Create a route table allowing all addresses to access the Gateway
resource "aws_route_table" "public_gateway_route" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  //  Use our common tags and add a specific name.
  tags = {
    Name    = "${var.cluster_name}-Public-Route-${random_string.random_name_post.result}"
    Account = data.aws_caller_identity.current.arn
    Type    = "FortiDemo-Terraform"

  }

}
//Nat Gateway route table
resource "aws_route_table" "nat_gateway_route" {
  vpc_id     = aws_vpc.main_vpc.id
  depends_on = [aws_network_interface.fgt_second_nic]
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_network_interface.fgt_second_nic.id
  }

  //  Use our common tags and add a specific name.
  tags = {
    Name    = "${var.cluster_name}-NatGateway-Route-${random_string.random_name_post.result}"
    Account = data.aws_caller_identity.current.arn
    Type    = "FortiDemo-Terraform"

  }

}
//Associate the Route with the main Subnet
resource "aws_route_table_association" "public-subnet" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.public_gateway_route.id
}
resource "aws_route_table_association" "public-subnet-secondary" {
  subnet_id      = aws_subnet.secondary.id
  route_table_id = aws_route_table.nat_gateway_route.id
  depends_on     = [aws_route_table.nat_gateway_route, aws_nat_gateway.gw]
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "${var.cluster_name}-s3-bucket-${random_string.random_name_post.result}"
  acl    = "public-read"
  tags = {
    Name    = "${var.cluster_name}-s3-${random_string.random_name_post.result}"
    Account = data.aws_caller_identity.current.arn
    Type    = "FortiDemo-Terraform"
  }
}

resource "aws_s3_bucket_object" "config_script" {
  bucket = aws_s3_bucket.s3_bucket.id
  key    = "runInspector.py"
  source = "${path.module}/runInspector.py.rendered"
  acl    = "aws-exec-read"
}
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "ubuntu_instance" {
  ami                    = data.aws_ami.ubuntu.id
  private_ip             = "10.0.2.100" //set to avoid cyclical condition with GW
  iam_instance_profile   = aws_iam_instance_profile.fortidemo.name
  availability_zone      = var.az_default
  key_name               = aws_key_pair.keypair.key_name
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.secondary.id
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  tags = {
    Name      = "${var.cluster_name}-Ubuntu-Instance-${random_string.random_name_post.result}"
    env       = "Inspector-${random_string.random_name_post.result}"
    ManagedBy = "Terraform"
    Account   = data.aws_caller_identity.current.arn
    Type      = "FortiDemo-Terraform"
    Account   = data.aws_caller_identity.current.arn


  } //Calling as a file makes syntax easier.
  user_data  = data.template_file.cloud-init.rendered
  depends_on = [aws_iam_role.fortidemo_iam_role]
}

//Additional Nic for Fortigate
resource "aws_network_interface" "fgt_primary_nic" {
  subnet_id = aws_subnet.main.id
  tags = {
    Name    = "primary_network_interface"
    Account = data.aws_caller_identity.current.arn
    Type    = "FortiDemo-Terraform"
  }
}
//Secondary nic
resource "aws_network_interface" "fgt_second_nic" {
  subnet_id       = aws_subnet.secondary.id
  security_groups = [aws_security_group.allow_all.id]
  //Source_dest_check must be turned off in order for egress traffic to work
  source_dest_check = false
  tags = {
    Name    = "secondary_network_interface"
    Account = data.aws_caller_identity.current.arn
    Type    = "FortiDemo-Terraform"
  }
  attachment {
    instance     = aws_instance.fortigate.id
    device_index = 1
  }
  depends_on = [aws_instance.fortigate]
}
resource "aws_instance" "fortigate" {
  ami                    = "ami-08f558c88d066cd22"                 //6.4.4 GA B1803  us-west-1
  iam_instance_profile   = aws_iam_instance_profile.fortidemo.name //IAM permissions for SDN connector
  availability_zone      = var.az_default
  instance_type          = "c5.large"
  subnet_id              = aws_subnet.main.id
  key_name               = aws_key_pair.keypair.key_name
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  user_data              = data.template_file.setup-nat-eip.rendered
  tags = {
    Name    = "${var.cluster_name}-FortiGate-${random_string.random_name_post.result}"
    Account = data.aws_caller_identity.current.arn
    Type    = "FortiDemo-Terraform"
  }
}
//FortiGate EIP
resource "aws_eip" "fortigate_eip" {
  vpc = true
  tags = {
    Name    = "${var.cluster_name}-Fortigate-EIP-${random_string.random_name_post.result}"
    Account = data.aws_caller_identity.current.arn
    Type    = "FortiDemo-Terraform"
  }
}
resource "aws_eip_association" "eip_association" {
  instance_id   = aws_instance.fortigate.id
  allocation_id = aws_eip.fortigate_eip.id

}

//Setup the Inspector
//specify the tags to look at
//Do not call env from instance to avoid cyclical condition
resource "aws_inspector_resource_group" "inspector_resource_group" {
  tags = {
    env = "Inspector-${random_string.random_name_post.result}"
  }
}

resource "aws_inspector_assessment_target" "inspector_assesment" {
  name               = "${var.cluster_name}-Inspector-Instance-${random_string.random_name_post.result}"
  resource_group_arn = aws_inspector_resource_group.inspector_resource_group.arn
}

resource "aws_inspector_assessment_template" "inspector_template" {
  name       = "Inspector-${random_string.random_name_post.result}"
  target_arn = aws_inspector_assessment_target.inspector_assesment.arn
  duration   = 300

  rules_package_arns = ["arn:aws:inspector:us-west-1:166987590008:rulespackage/0-TKgzoVOa"]
}


output "InstanceID" {
  value = aws_instance.fortigate.id
}
output "FortiGate_Public_IP" {
  value = aws_eip.fortigate_eip.public_ip
}
output "InstanceName" {
  value = aws_instance.fortigate.tags.Name
}
output "PrivateIP" {
  value = aws_network_interface.fgt_second_nic.private_ip
}
output "data" {
  value = data.external.external_ip.result
}
output "token" {
  value = data.external.setup_api_key.result.token
}