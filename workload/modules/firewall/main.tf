resource "azurerm_firewall_policy" "policy" {
  name                = var.policy_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"  

  threat_intelligence_mode = "Deny"  

  dns {
    proxy_enabled = true            
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "main" {
  name               = var.rule_collection_group_name
  firewall_policy_id = azurerm_firewall_policy.policy.id
  priority           = 100

  network_rule_collection {
    name     = "aca-required"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "aca-service-tags"
      protocols             = ["TCP"]
      source_addresses      = var.aca_rule_source_addresses
      destination_addresses = var.aca_rule_destination_service_tags
      destination_ports = ["443"]
    }
  }

  application_rule_collection {
    name     = "testcollection"
    priority = 200
    action   = "Allow"

    rule {
      name             = "FW_demo_rule"
      source_addresses = var.app_rule_source_addresses

      destination_fqdns = var.app_rule_destination_fqdns

      protocols {
        type = "Https"
        port = 443
      }
    }
    rule {
      name               = "ubuntu_apt_http"
      source_addresses   = var.apt_rule_source_addresses
      destination_fqdns  = var.apt_rule_destination_fqdns

      protocols {
        port = "80"
        type = "Http"
      }
    }
  }
}

resource "azurerm_firewall" "firewall" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.policy.id

  ip_configuration {
    name                 = "FW_configuration"
    subnet_id            = var.firewall_subnet_id
    public_ip_address_id = var.public_ip_id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.main]
}

resource "azurerm_route_table" "rt" {
  name                = var.route_table_name
  location            = var.location
  resource_group_name = var.resource_group_name

  route {
    name                   = "route1"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.firewall.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "route" {
  for_each       = var.spoke_subnet_ids
  subnet_id      = each.value
  route_table_id = azurerm_route_table.rt.id

  depends_on = [
    azurerm_firewall.firewall, 
    azurerm_firewall_policy_rule_collection_group.main
  ]
}

resource "azurerm_subnet_route_table_association" "route-ghr" {
  subnet_id      = var.aca_subnet_id
  route_table_id = azurerm_route_table.rt.id

  depends_on = [
    azurerm_firewall.firewall,
    azurerm_firewall_policy_rule_collection_group.main,
    azurerm_subnet_route_table_association.route
  ]
}
