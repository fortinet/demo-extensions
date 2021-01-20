#Provider Information


#Hostname
resource "fortios_system_global" "hostname" {
  hostname  = "FortiDEMO_AWS"
}

#Administrator
resource "fortios_system_admin" "administrator" {
  name = "cloudadmin"
  password = "${var.admin_pass}"
}

#Interface
resource "fortios_system_interface" "interfaces" {
  name         = "port1"
  vdom         = "root"
  mode         = "dhcp"
  allowaccess  = "ping https ssh fgfm"
  description  = "Created by Terraform Provider for FortiOS"
}

resource "fortios_system_interface" "port2" {
  name                    = "port2"
  vdom                    = "root"
  mode                    = "dhcp"
  allowaccess             = "ping ssh"
  description             = "Created by Terraform Provider for FortiOS"
  defaultgw               = "disable"
  device_identification   = "enable"
  scan_botnet_connections = "enable"
 }

#Firewall Settings - VIP
resource "fortios_firewall_vip" "toUbunutuVIP" {
  name = "toUbunutuVIP"
  comment = "VIP to Ubuntu"
  extintf = "port1"
  portforward = "enable"
  extport = "22"
  mappedport = "22"

  mappedip {
    range = "${var.ubuntu_instance_ip}"
  }
}

#Firewall Addresses
resource "fortios_firewall_address" "local" {
  name = "Fortidemo_local_subnet_1"
  allow_routing = "enable"
  subnet = "10.0.1.0 255.255.255.0"
}

resource "fortios_firewall_address" "remote" {
  name = "FortiDEMO_remote_subnet_1"
  allow_routing = "enable"
  subnet = "10.100.88.0 255.255.255.0"
}

#Firewall Address Groups
resource "fortios_firewall_addrgrp" "local" {
  name = "FortiDEMO_local"
  member {
    name = "FortiDEMO_local_subnet_1"
    }
  allow_routing = "enable"
  visibility = "enable"
}

resource "fortios_firewall_addrgrp" "remote" {
  name = "FortiDEMO_remote"
  member {
    name = "FortiDEMO_remote_subnet_1"
  }
  allow_routing = "enable"
  visibility = "enable"
}

#VPN IPsec phase1-interface
resource "fortios_vpnipsec_phase1interface" "FortiDEMOphase1" {
  name = "FortiDEMOphase1"
  interface = "port1"
  peertype = "any"
  net_device = "enable"
  proposal = "aes128-sha256 aes256-sha256 aes128-sha1 aes256-sha1"
  wizard_type = "static-fortigate"
  remote_gw = "${var.fortidemo_ip}"
  psksecret = "fortidemo"
}

#VPN IPsec phase2-interface
resource "fortios_vpnipsec_phase2interface" "FortiDEMOphase2" {
  name = "FortiDEMOphase2"
  phase1name = "FortiDEMOphase2"
  proposal = "aes128-sha1 aes256-sha1 aes128-sha256 aes256-sha256 aes128gcm aes256gcm chacha20poly1305"
  src_addr_type = "name"
  dst_addr_type = "name"
  src_name = "FortiDEMO_local"
  dst_name = "FortiDEMO_remote"
 }

#VPN Firewall Policies
resource "fortios_firewall_policy" "vpnpolicy1" {
  policyid = 1
  name = "vpn_FortiDEMO_local"
  action = "accept"
  nat = "enable"
  schedule = "always"

  srcintf {
    name = "port1"
  }

  dstintf {
    name = "FortiDemo"
  }

  srcaddr {
    name = "FortiDEMO_local"
  }

  dstaddr {
    name = "FortiDEMO_remote"
  }

  service {
    name = "ALL"
  }

}

resource "fortios_firewall_policy" "vpnpolicy2" {
  policyid = 2
  name = "vpn_FortiDEMO_remote"
  action = "accept"
  nat = "enable"
  schedule = "always"

  srcintf {
    name = "FortiDEMO"
  }

  dstintf {
    name = "port1"
  }

  srcaddr {
    name = "FortiDEMO_remote"
  }

  dstaddr {
    name = "FortiDEMO_local"
  }

  service {
    name = "ALL"
  }
}

#Router Configuration
resource "fortios_router_static" "Access" {
  dst = "0.0.0.0 0.0.0.0"
  device = "FortiDEMO"
  dstaddr = "FortiDEMO_remote" 
  seq_num = 1
}

resource "fortios_router_static" "blackhole" {
  dst = "0.0.0.0 0.0.0.0"
  blackhole = "enable"
  distance = 254
  dstaddr = "FortiDEMO_remote"
  seq_num = 2
}

#Firewall Policies
resource "fortios_firewall_policy" "policy1" {
  policyid = 3
  name = "port1 to port1"
  action = "accept"
  nat = "enable"
  schedule = "always"

  srcintf {
    name = "port1"
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

resource "fortios_firewall_policy" "policy2" {
  policyid = 4
  name = "ToUbuntu"
  action = "accept"
  nat = "enable"
  schedule = "always"
  utm_status = "enable"
  fixedport = "enable"
  fsso = "enable"
  av_profile = "default"
  ssl_ssh_profile = "certificate-inspection"

  srcintf {
    name = "port1"
  }

  dstintf {
    name = "port2"
  }

  srcaddr {
    name = "all"
  }

  dstaddr {
    name = "ToUbuntuVIP"
  }

  service {
    name = "HTTP"
  }

  service {
    name = "SSH"
  }
}

resource "fortios_firewall_policy" "policy3" {
  policyid = 5
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

#VPN Certificate Remote
resource "fortios_vpncertificate_remote" "TEMP_Cert_1" {
  name = "TEMP_Cert_1"
  remote = var.temp_cert
}

#SAML Settings
resource "fortios_system_saml" "SAML" {
  status = "enable"
  role = "service-provider"
  idp_entity_id = "http://2.2.2.2:10403/saml-idp/csf_s3n6f2jbdvf2mecjd0qtau9qdrlg02x/metadata/"
  idp_single_sign_on_url = "https://2.2.2.2:10403/saml-idp/csf_s3n6f2jbdvf2mecjd0qtau9qdrlg02x/login/"
  idp_single_logout_url = "https://2.2.2.2:10403/saml-idp/csf_s3n6f2jbdvf2mecjd0qtau9qdrlg02x/logout/"
  default_login_page = "normal"
  default_profile = "super_admin"
  idp_cert = "TEMP_Cert_1"
  server_address = "'${var.aws_eip}':443"
}

#CSF Settings
resource "fortios_system_csf" "csfSettings" {
  status = "enable"
  upstream_ip = "10.100.88.1"
  management_ip = "${var.aws_eip}"
  management_port = 443
}

#SDN Connector
resource "fortios_system_sdnconnector" "awsSdn" {
  name = "awsSDN"
  status = "enable"
  type = "aws"
  use_metadata_iam = "enable"
}
