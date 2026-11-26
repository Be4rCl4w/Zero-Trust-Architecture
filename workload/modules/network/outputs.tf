output "hub_subnets" {
  description = "Hub subnets created by this module: name => { id, address_prefixes }."
  value = {
    for k, s in azurerm_subnet.Hub_vnet_subnets : k => {
      id               = s.id
      address_prefixes = s.address_prefixes
    }
  }
}

output "spoke_subnets" {
  description = "Spoke subnets created by this module: name => { id, address_prefixes }."
  value = {
    for k, s in azurerm_subnet.Spoke_vnet_subnets : k => {
      id               = s.id
      address_prefixes = s.address_prefixes
    }
  }
}

output "public_ips" {
  description = "Public IPs: name => { id, ip_address, fqdn }."
  value = {
    for k, p in azurerm_public_ip.public_ip : k => {
      id         = p.id
      ip_address = p.ip_address
      fqdn       = p.fqdn
    }
  }
}
