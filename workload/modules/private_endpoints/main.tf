locals {
  # One entry per zone/VNet pair
  dns_links = merge([
    for zone_key, zone in var.dns_zones : {
      for vnet_key in zone.vnets :
      "${zone_key}-${vnet_key}" => {
        zone_key = zone_key
        vnet_id  = var.vnets[vnet_key]
      }
    }
  ]...)
}

resource "azurerm_private_dns_zone" "private_dns_zone" {
  for_each            = var.dns_zones
  name                = each.value.name
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_link" {
  for_each              = local.dns_links
  name                  = "demo_${each.key}_link"
  private_dns_zone_id   = azurerm_private_dns_zone.private_dns_zone[each.value.zone_key].id
  virtual_network_id    = each.value.vnet_id
}

resource "azurerm_private_endpoint" "private_endpoint" {
  for_each            = var.endpoints
  name                = "${each.key}-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = each.value.subnet_id

  private_service_connection {
    name                           = "${each.key}-privateserviceconnection"
    private_connection_resource_id = each.value.resource_id
    is_manual_connection           = false
    subresource_names              = [each.value.subresource]
  }

  private_dns_zone_group {
    name                 = "${each.key}-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zone[each.value.dns_key].id]
  }
}
