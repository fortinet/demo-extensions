//AWS Configuration
variable access_key {
    type = string
    default = ""
}

variable secret_key {
    type = string
    default = ""
}

variable "region" {
  type = string
  default = "us-west-1"
}

// Availability zones for the region
variable "az1" {
  type = string
  default = "us-west-1a"
}

variable "az2" {
  type = string
  default = "us-west-1b"
}

// AWS EIP
variable "aws_eip" {
  type = string
  default = "aws_eip.fortigate_eip.public_ip"
}

//Ubuntu Instance IP address
variable "ubuntu_instance_ip" {
  type = string
  default = "10.0.2.100"
}

//User Admin Password
variable "admin_pass" {
  type  = string
  default = "Password1!"
}

// Certificate File
variable "temp_cert"{
    type = string
    default = "TEMP_Cert_1.pem"
}