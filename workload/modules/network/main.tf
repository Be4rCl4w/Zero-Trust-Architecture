resource "azurerm_subnet" "Spoke_vnet_subnets" {
  for_each             = var.spoke_subnets
  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.spoke_vnet_name
  address_prefixes     = [each.value.address_prefix]

  private_endpoint_network_policies = each.value.pe_policies

  # Conditionally add delegation block using dynamic
  dynamic "delegation" {
    for_each = each.value.delegate ? [1] : []

    content {
      name = "app-service-delegation"

      service_delegation {
        name    = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
  }
}

resource "azurerm_subnet" "Hub_vnet_subnets" {
  for_each             = var.hub_subnets
  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.hub_vnet_name
  address_prefixes     = [each.value]
}

resource "azurerm_public_ip" "public_ip" {
  for_each            = toset(var.public_ip_names)
  name                = each.key
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  # Dynamically inject the label ONLY if the current item is "AppGateway"
  domain_name_label = each.value == "AppGateway" ? var.app_gw_dns_prefix : null
}
