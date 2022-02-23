resource "fortios_firewall_vip" "ubuntuVIP" {
  name        = "toUbuntuVIP"
  comment     = "VIP to Ubuntu"
  extintf     = "port1"
  portforward = "enable"
  extport     = "422"
  mappedport  = "22"

  mappedip {
    range = "10.0.2.100"
  }
}

#System > Interface > port1
resource "fortios_system_interface" "interfaces" {
  name          = "port1"
  vdom          = "root"
  mode          = "dhcp"
  allowaccess   = "ping https ssh fgfm"
  description   = "Created by Terraform Provider for FortiOS"
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
  autogenerated           = "auto"
}

#VPN Firewall Addresses
resource "fortios_firewall_address" "local" {
  name          = "Fortidemo_local_subnet_1"
  allow_routing = "enable"
  subnet        = "10.0.1.0 255.255.255.0"
}

resource "fortios_firewall_address" "remote" {
  name          = "FortiDEMO_remote_subnet_1"
  allow_routing = "enable"
  subnet        = "10.100.88.0 255.255.255.0"
}

#VPN Firewall Address Groups
resource "fortios_firewall_addrgrp" "FortiDEMO_local" {
  name = "FortiDEMO_local"
  member {
    name = fortios_firewall_address.local.name
  }
  allow_routing = "enable"
  visibility    = "enable"
}

resource "fortios_firewall_addrgrp" "FortiDEMO_remote" {
  name = "FortiDEMO_remote"
  member {
    name = fortios_firewall_address.remote.name
  }
  allow_routing = "enable"
  visibility    = "enable"
}

#VPN IPsec phase2-interface
resource "fortios_vpnipsec_phase2interface" "FortiDEMOphase2" {
  name          = "FortiDEMO"
  phase1name    = fortios_vpnipsec_phase1interface.FortiDEMOphase1.name
  proposal      = "aes128-sha1 aes256-sha1 aes128-sha256 aes256-sha256 aes128gcm aes256gcm chacha20poly1305"
  src_addr_type = "name"
  dst_addr_type = "name"
  src_name      = "FortiDEMO_local"
  dst_name      = "FortiDEMO_remote"

  depends_on = [
    fortios_vpnipsec_phase1interface.FortiDEMOphase1,
    fortios_firewall_address.local,
    fortios_firewall_address.remote,
  ]
}

#VPN Firewall Policy1
resource "fortios_firewall_policy" "vpnpolicy1" {
  policyid = 100
  name     = "vpn_FortiDEMO_local"
  action   = "accept"
  nat      = "enable"
  schedule = "always"

  srcintf {
    name = "port1"
  }

  dstintf {
    name = "FortiDEMO"
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

  depends_on = [
    fortios_system_interface.FortiDEMOinterface
  ]
}

#VPN Firewall Policy2
resource "fortios_firewall_policy" "vpnpolicy2" {
  policyid = 101
  name     = "vpn_FortiDEMO_remote"
  action   = "accept"
  nat      = "enable"
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

  depends_on = [
    fortios_system_interface.FortiDEMOinterface
  ]
}

#Firewall Policy 1
resource "fortios_firewall_policy" "policy1" {
  policyid = 103
  name     = "port1 to port1"
  action   = "accept"
  nat      = "enable"
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

#Firewall Policy 2
resource "fortios_firewall_policy" "policy2" {
  policyid        = 104
  name            = "toUbuntu"
  action          = "accept"
  nat             = "enable"
  schedule        = "always"
  utm_status      = "enable"
  fixedport       = "enable"
  fsso            = "enable"
  av_profile      = "default"
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
    name = "toUbuntuVIP"
  }

  service {
    name = "HTTP"
  }

  service {
    name = "SSH"
  }

  depends_on = [
    fortios_firewall_vip.ubuntuVIP
  ]
}

#Firewall Policy 3
resource "fortios_firewall_policy" "policy3" {
  policyid        = 105
  name            = "UbuntuEgress"
  action          = "accept"
  nat             = "enable"
  schedule        = "always"
  utm_status      = "enable"
  fixedport       = "enable"
  fsso            = "disable"
  av_profile      = "default"
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

#VPN Interface
resource "fortios_system_interface" "FortiDEMOinterface" {
  name          = fortios_vpnipsec_phase2interface.FortiDEMOphase2.name
  description   = "VPN Interface"
  type          = "tunnel"
  vdom          = "root"
  allowaccess   = "ping ssh fabric"
  ip            = "0.0.0.0 0.0.0.0"
  remote_ip     = "0.0.0.0 0.0.0.0"
  tcp_mss       = 1400
  autogenerated = "auto"
}

#Router Configuration
resource "fortios_router_static" "Access" {
  dst     = "0.0.0.0 0.0.0.0"
  device  = "FortiDEMO"
  dstaddr = "FortiDEMO_remote"
  seq_num = 1

  depends_on = [
    fortios_system_interface.FortiDEMOinterface
  ]
}

resource "fortios_router_static" "blackhole" {
  dst       = "0.0.0.0 0.0.0.0"
  blackhole = "enable"
  distance  = 254
  dstaddr   = "FortiDEMO_remote"
  seq_num   = 2

  depends_on = [
    fortios_system_interface.FortiDEMOinterface
  ]
}

#SDN Connector
resource "fortios_system_sdnconnector" "awsSdn" {
  name             = "awsSDN"
  status           = "enable"
  type             = "aws"
  use_metadata_iam = "enable"
}
