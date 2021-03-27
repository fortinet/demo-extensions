#Hostname
resource "fortios_system_global" "hostname" {
  hostname  = "FortiDEMO_AWS"
}

#System > Interface > port1
resource "fortios_system_interface" "interfaces" {
  name         = "port1"
  vdom         = "root"
  mode         = "dhcp"
  allowaccess  = "ping https ssh fgfm"
  description  = "Created by Terraform Provider for FortiOS"
  autogenerated = "auto"
}

#System > Interface > port2
resource "fortios_system_interface" "port2" {
  name                    = "port2"
  vdom                    = "root"
  mode                    = "dhcp"
  allowaccess             = "ping ssh"
  description             = "Created by Terraform Provider for FortiOS"
  defaultgw               = "disable"
  device_identification   = "enable"
  scan_botnet_connections = "enable"
  autogenerated = "auto"
 }

#Firewall Policies (3)
resource "fortios_firewall_policy" "policy3" {
  policyid = 105
  name = "UbuntuEgress"
  action = "accept"
  nat = "enable"
  schedule = "always"
  utm_status = "enable"
  fixedport = "enable"
  fsso = "disable"
  av_profile = "default"
  ssl_ssh_profile = "certificate-inspection"

  srcintf {
    name = "port2"
  }

  dstintf {
    name = "port1"
  }

  srcaddr {
    name = "all"
  }

  dstaddr {
    name = "all"
  }

  service {
    name = "ALL"
  }
}

#SDN Connector
resource "fortios_system_sdnconnector" "awsSdn" {
  name = "awsSDN"
  status = "enable"
  type = "aws"
  use_metadata_iam = "enable"
}