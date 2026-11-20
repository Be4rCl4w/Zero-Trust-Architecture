terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.81.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">=3.5.0"
    }
  }
}

provider "azuread" {}
provider "azurerm" {
  features {}
}

data "azurerm_log_analytics_workspace" "law" {
  name                = "DefaultWorkspace-0af19ed5-487a-47e1-bc21-11f4ae6bc5a8-NEU"
  resource_group_name = "defaultresourcegroup-neu"
}

data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = "Demo-RG1"
}

data "azurerm_virtual_network" "Hub_vnet" {
  name                = "Hub_demo_vnet"
  resource_group_name = "Demo-RG1"
}

data "azurerm_virtual_network" "Spoke_vnet" {
  name                = "Spoke_demo_vnet"
  resource_group_name = "Demo-RG1"
}

data "azurerm_subnet" "aca" {
  name                 = "ACA-JobSubnet"
  virtual_network_name = "Hub_demo_vnet"
  resource_group_name  = "Demo-RG1"
}

data "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  virtual_network_name = "Hub_demo_vnet"
  resource_group_name  = "Demo-RG1"
}

data "azurerm_container_registry" "acr" {
  name                = "myghrunneracr123"
  resource_group_name = "Demo-RG1"
}

data "azurerm_key_vault" "kv" {
  name                = "Deemo-kv213"
  resource_group_name = "Demo-RG1"
}

resource "azurerm_application_insights" "appi" {
  name                = "demo-appi"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = data.azurerm_log_analytics_workspace.law.id
}


resource "azurerm_user_assigned_identity" "appgw_identity" {
  name                = "appgw-managed-identity"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
}

locals {
  Hub_subnets = {
    "AzureBastionSubnet"  = "10.0.1.0/27"
    "AppGatewaySubnet"    = "10.0.2.0/26"
  }
}

locals {
  Spoke_subnets = {
    "WebSubnet" = {
      address_prefix = "10.20.0.0/24"
      delegate       = true # delegation (App Service VNet integration, outbound only)
      pe_policies    = "Disabled"
    }
    "AppSubnet" = {
      address_prefix = "10.20.1.0/24"
      delegate       = false
      pe_policies    = "Disabled"
    }
    "DataSubnet" = {
      address_prefix = "10.20.3.0/24"
      delegate       = false
      pe_policies    = "Enabled"
    }
    "InfraPrivateEndpointsSubnet" = {
      address_prefix = "10.20.4.0/24"
      delegate       = false
      pe_policies    = "Enabled" # makes NSG rules apply to private endpoints
    }
    "WebEndpointSubnet" = {
      address_prefix = "10.20.5.0/24"
      delegate       = false
      pe_policies    = "Enabled"
    }
  }

  # Static private frontend IP of the internal load balancer
  app_lb_private_ip = cidrhost(local.Spoke_subnets["AppSubnet"].address_prefix, 10)
}

resource "azurerm_subnet" "Spoke_vnet_subnets" {
  for_each             = local.Spoke_subnets
  name                 = each.key
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.Spoke_vnet.name
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
  for_each             = local.Hub_subnets
  name                 = each.key
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.Hub_vnet.name
  address_prefixes     = [each.value]
}

locals {
  Public_ip_addresses = [
    "AppGateway",
    "AzureFirewall" #Remember to add the comma
    #"AzureBastion" 
  ]

  app_gw_dns_prefix = "zero-trust-voteapp" 
}

resource "azurerm_public_ip" "public_ip" {
  for_each            = toset(local.Public_ip_addresses)
  name                = each.key
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  # Dynamically inject the label ONLY if the current item is "AppGateway"
  domain_name_label = each.value == "AppGateway" ? local.app_gw_dns_prefix : null
}

resource "azurerm_firewall" "firewall" {
  name                = "demo_firewall"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "FW_configuration"
    subnet_id            = data.azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.public_ip["AzureFirewall"].id
  }

  dns_proxy_enabled = true
  threat_intel_mode = "Deny"
}

resource "azurerm_firewall_application_rule_collection" "fwrc" {
  name                = "testcollection"
  azure_firewall_name = azurerm_firewall.firewall.name
  resource_group_name = data.azurerm_resource_group.rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "FW_demo_rule"

    source_addresses = [
      "10.20.0.0/16", 
      "10.0.3.0/24"
    ]

     target_fqdns = [
      "github.com", "*.github.com", "*.actions.githubusercontent.com",
      "*.githubusercontent.com", "*.blob.core.windows.net",
      "*.azurecr.io", "*.vault.azure.net", "login.microsoftonline.com",
      "*.azure.com", "*.microsoft.com", "mcr.microsoft.com", "*.data.mcr.microsoft.com",
      "releases.hashicorp.com", "registry.terraform.io", "*.ubuntu.com"
    ]

    protocol {
      port = "443"
      type = "Https"
    }
  }
}

resource "azurerm_firewall_network_rule_collection" "aca" {
  name                = "aca-required"
  azure_firewall_name = azurerm_firewall.firewall.name
  resource_group_name = data.azurerm_resource_group.rg.name
  priority            = 110
  action              = "Allow"

  rule {
    name                  = "aca-service-tags"
    source_addresses      = ["10.0.3.0/26"]
    destination_addresses = ["MicrosoftContainerRegistry", "AzureFrontDoor.FirstParty", "AzureActiveDirectory", "AzureContainerRegistry", "AzureKeyVault"]
    destination_ports     = ["443"]
    protocols             = ["TCP"]
  }
}

resource "azurerm_route_table" "rt" {
  name                = "demo-route-table"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  route {
    name                   = "route1"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.firewall.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "route" {
  for_each       = local.Spoke_subnets
  subnet_id      = azurerm_subnet.Spoke_vnet_subnets[each.key].id
  route_table_id = azurerm_route_table.rt.id
}

resource "azurerm_subnet_route_table_association" "route-ghr" {
  subnet_id      = data.azurerm_subnet.aca.id
  route_table_id = azurerm_route_table.rt.id
}


#resource "azurerm_bastion_host" "bastion" {
  #name                = "demo_bastion"
  #location            = data.azurerm_resource_group.rg.location
  #resource_group_name = data.azurerm_resource_group.rg.name
  #sku                 = "Standard"
  #tunneling_enabled   = true

  #ip_configuration {
    #name                 = "demo_bastion_ip_config"
    #subnet_id            = azurerm_subnet.Hub_vnet_subnets["AzureBastionSubnet"].id
    #public_ip_address_id = azurerm_public_ip.public_ip["AzureBastion"].id
  #}
#}

locals {
  dns_zones = {
    sql = {
      name    = "privatelink.database.windows.net"
      vnet_id = data.azurerm_virtual_network.Spoke_vnet.id   # <-- different VNet for SQL
    }
    kv = {
      name    = "privatelink.vaultcore.azure.net"
      vnet_id = data.azurerm_virtual_network.Spoke_vnet.id
    }
    webapp = {
      name    = "privatelink.azurewebsites.net"
      vnet_id = data.azurerm_virtual_network.Spoke_vnet.id
    }
    acr = {
      name    = "privatelink.azurecr.io"
      vnet_id = data.azurerm_virtual_network.Spoke_vnet.id
    }
  }
}

resource "azurerm_private_dns_zone" "private_dns_zone" {
  for_each            = local.dns_zones
  name                = each.value.name
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_link" {
  for_each              = local.dns_zones
  name                  = "demo_${each.key}_link"
  private_dns_zone_id = azurerm_private_dns_zone.private_dns_zone[each.key].id
  virtual_network_id    = each.value.vnet_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "webapp_runner" {
  name                = "webapp-runner-link"
  private_dns_zone_id = azurerm_private_dns_zone.webapp.id
  virtual_network_id  = data.azurerm_virtual_network.Hub_vnet.id
}

locals {
  endpoints_config = {
    sql = {
      dns_key     = "sql"
      resource_id = azurerm_mssql_server.sql_server.id
      subresource = "sqlServer"
      subnet_id   = azurerm_subnet.Spoke_vnet_subnets["DataSubnet"].id   # <-- different subnet for SQL
    }
    kv = {
      dns_key     = "kv"
      resource_id = data.azurerm_key_vault.kv.id
      subresource = "vault"
      subnet_id   = azurerm_subnet.Spoke_vnet_subnets["WebEndpointSubnet"].id
    }
    webapp = {
      dns_key     = "webapp"
      resource_id = azurerm_linux_web_app.webapp.id
      subresource = "sites"
      subnet_id   = azurerm_subnet.Spoke_vnet_subnets["WebEndpointSubnet"].id
    }
    acr = {
      dns_key     = "acr"
      resource_id = data.azurerm_container_registry.acr.id
      subresource = "registry"
      subnet_id   = azurerm_subnet.Spoke_vnet_subnets["InfraPrivateEndpointsSubnet"].id
    }
  }
}

resource "azurerm_private_endpoint" "private_endpoint" {
  for_each            = local.endpoints_config
  name                = "${each.key}-private-endpoint"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
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

############################################
# App Gateway NSG
############################################
resource "azurerm_network_security_group" "appgw" {
  name                = "Demo-appGW-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "appGW-in-https"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges     = ["443", "80"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    description                = "HTTPS from internet."
  }

    security_rule {
    name                       = "appGW-in-gatewaymanager"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
    description                = "Required for App Gateway v2 management"
  }

  security_rule {
    name                       = "appGW-in-azureloadbalancer"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer" # Added to permit internal health probes
    destination_address_prefix = "*"
    description                = "Allow Azure Load Balancer Probes"
  }

  security_rule {
    name                       = "appGW-in-deny-all"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit deny all inbound"
  }

  security_rule {
    name                         = "appGW-out-to-web"
    priority                     = 100
    direction                    = "Outbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "80"
    source_address_prefixes      = azurerm_subnet.Hub_vnet_subnets["AppGatewaySubnet"].address_prefixes
    destination_address_prefixes = azurerm_subnet.Spoke_vnet_subnets["WebEndpointSubnet"].address_prefixes
    description                  = "App Gateway to web tier on port 80"
  }

  security_rule {
    name                         = "appGW-out-to-internet"
    priority                     = 200
    direction                    = "Outbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_ranges      = ["443", "80"]
    source_address_prefixes      = azurerm_subnet.Hub_vnet_subnets["AppGatewaySubnet"].address_prefixes
    destination_address_prefix   = "Internet" # Added to allow CRL verification & backend communications
    description                  = "Allow outbound to internet for CRL verification"
  }


  security_rule {
    name                         = "appGW-out-to-kv"
    priority                     = 300
    direction                    = "Outbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefixes      = azurerm_subnet.Hub_vnet_subnets["AppGatewaySubnet"].address_prefixes
    destination_address_prefixes = azurerm_subnet.Spoke_vnet_subnets["WebEndpointSubnet"].address_prefixes
    description                  = "App Gateway to Key Vault"
  }

  security_rule {
    name                       = "appGW-out-to-vnet"
    priority                   = 400
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
    description                = "Allow VNet-internal traffic"
  }

}

############################################
# Web NSG
############################################
resource "azurerm_network_security_group" "web" {
  name                = "Demo-web-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "web-in-deny-all"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit deny all inbound"
  }

  # Proxy calls the LB frontend on 80 (source-side NSG sees the pre-NAT destination)
  security_rule {
    name                       = "web-out-to-app-lb"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "8080", "3000"]
    source_address_prefixes    = azurerm_subnet.Spoke_vnet_subnets["WebSubnet"].address_prefixes
    destination_address_prefix = local.app_lb_private_ip
    description                = "Web tier to internal LB frontend only"
  }

  security_rule {
    name                       = "web-out-deny-all"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit deny all outbound"
  }
}

############################################
# App NSG
############################################
resource "azurerm_network_security_group" "app" {
  name                = "Demo-app-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                         = "app-in-from-web"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_ranges      = ["3000", "80"]
    source_address_prefixes      = azurerm_subnet.Spoke_vnet_subnets["WebSubnet"].address_prefixes
    destination_address_prefixes = azurerm_subnet.Spoke_vnet_subnets["AppSubnet"].address_prefixes
    description                  = "Only the web tier can reach the app port"
  }

  security_rule {
    name                         = "Allow-LB-Probes"
    priority                     = 200
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "3000"
    source_address_prefix        = "AzureLoadBalancer"
    destination_address_prefixes = azurerm_subnet.Spoke_vnet_subnets["AppSubnet"].address_prefixes
    description                  = "Internal LB health probe"
  }

  security_rule {
    name                         = "app-in-admin-bastion"
    priority                     = 300
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "22"
    source_address_prefixes      = azurerm_subnet.Hub_vnet_subnets["AzureBastionSubnet"].address_prefixes
    destination_address_prefixes = azurerm_subnet.Spoke_vnet_subnets["AppSubnet"].address_prefixes
    description                  = "Admin access via Bastion only"
  }

  security_rule {
    name                         = "app-in-github-runner"
    priority                     = 400
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_ranges      = ["22", "443"]
    source_address_prefixes      = data.azurerm_subnet.aca.address_prefixes
    destination_address_prefixes = azurerm_subnet.Spoke_vnet_subnets["AppSubnet"].address_prefixes
    description                  = "GitHub Runner access"
  }

  security_rule {
    name                       = "app-in-deny-all"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit deny all inbound"
  }

  security_rule {
    name                         = "app-out-to-db"
    priority                     = 100
    direction                    = "Outbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "1433"
    source_address_prefixes      = azurerm_subnet.Spoke_vnet_subnets["AppSubnet"].address_prefixes
    destination_address_prefixes = azurerm_subnet.Spoke_vnet_subnets["DataSubnet"].address_prefixes
    description                  = "App to database on DB port only"
  }

  security_rule {
    name                         = "app-out-for-AADSSHLoginForLinux-setup"
    priority                     = 300
    direction                    = "Outbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_ranges      = ["80", "443"]
    source_address_prefixes      = azurerm_subnet.Spoke_vnet_subnets["AppSubnet"].address_prefixes
    destination_address_prefix   = "Internet"
    description                  = "Allow outbound to internet for AADSSHLoginForLinux setup"
  }

  security_rule {
    name                       = "app-out-deny-all"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit deny all outbound"
  }
}

############################################
# DB NSG
############################################
resource "azurerm_network_security_group" "db" {
  name                = "Demo-db-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                         = "db-in-from-app"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "1433"
    source_address_prefixes      = azurerm_subnet.Spoke_vnet_subnets["AppSubnet"].address_prefixes
    destination_address_prefixes = azurerm_subnet.Spoke_vnet_subnets["DataSubnet"].address_prefixes
    description                  = "Only the app tier can reach the DB port"
  }

  security_rule {
    name                       = "db-in-deny-all"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit deny all inbound"
  }

  security_rule {
    name                       = "db-out-deny-all"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit deny all outbound"
  }
}


############################################
# Infra-PE NSG
############################################
resource "azurerm_network_security_group" "pe" {
  name                = "Demo-Infra-PE-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                         = "PE-in-from-ACA"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefixes      = data.azurerm_subnet.aca.address_prefixes
    destination_address_prefixes = azurerm_subnet.Spoke_vnet_subnets["InfraPrivateEndpointsSubnet"].address_prefixes
    description                  = "ACA to ACR private endpoint"
  }

  security_rule {
    name                       = "PE-in-deny-all"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit deny all inbound"
  }

  security_rule {
    name                       = "PE-out-deny-all"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit deny all outbound"
  }
}

############################################
# Web-PE NSG
############################################
resource "azurerm_network_security_group" "web-pe" {
  name                = "Demo-Web-PE-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                         = "PE-in-from-appGW"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefixes      = azurerm_subnet.Hub_vnet_subnets["AppGatewaySubnet"].address_prefixes
    destination_address_prefixes = azurerm_subnet.Spoke_vnet_subnets["WebEndpointSubnet"].address_prefixes
    description                  = "App Gateway to web app and key vault endpoints (HTTPS)"
  }
  security_rule {
    name                         = "PE-in-from-ACA"
    priority                     = 200
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefixes      = data.azurerm_subnet.aca.address_prefixes
    destination_address_prefixes = azurerm_subnet.Spoke_vnet_subnets["WebEndpointSubnet"].address_prefixes
    description                  = "ACA to web app and key vault endpoints (HTTPS)"
  }

  security_rule {
    name                       = "PE-in-deny-all"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit deny all inbound"
  }

  security_rule {
    name                       = "PE-out-deny-all"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit deny all outbound"
  }
}

############################################
# Subnet associations
############################################
resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.Hub_vnet_subnets["AppGatewaySubnet"].id
  network_security_group_id = azurerm_network_security_group.appgw.id
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.Spoke_vnet_subnets["WebSubnet"].id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.Spoke_vnet_subnets["AppSubnet"].id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.Spoke_vnet_subnets["DataSubnet"].id
  network_security_group_id = azurerm_network_security_group.db.id
}

resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = azurerm_subnet.Spoke_vnet_subnets["InfraPrivateEndpointsSubnet"].id
  network_security_group_id = azurerm_network_security_group.pe.id
}

resource "azurerm_subnet_network_security_group_association" "web-pe" {
  subnet_id                 = azurerm_subnet.Spoke_vnet_subnets["WebEndpointSubnet"].id
  network_security_group_id = azurerm_network_security_group.web-pe.id
}

resource "azurerm_application_gateway" "appgw" {
  name                = "example-appgw"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.Hub_vnet_subnets["AppGatewaySubnet"].id
  }

  # --- FRONTEND PORTS ---
  frontend_port {
    name = "frontendPortHttps" # Split into unique names
    port = 443
  }

  frontend_port {
    name = "frontendPortHttp"  # Added distinct port 80 for HTTP
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontendIpConfig"
    public_ip_address_id = azurerm_public_ip.public_ip["AppGateway"].id
  }

  backend_address_pool {
    name = "backendPool"
    fqdns = [azurerm_linux_web_app.webapp.default_hostname]
  }

  probe {
    name                                      = "demo-probe"
    protocol                                  = "Https"
    path                                      = "/healthz"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-399"]
    }
  }

  backend_http_settings {
    name                                = "backendHttpSettings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
    probe_name                          = "demo-probe"
  }

  # --- LISTENERS ---
  http_listener {
    name                           = "httpsListener"
    frontend_ip_configuration_name = "frontendIpConfig"
    frontend_port_name             = "frontendPortHttps" # Points to 443
    protocol                       = "Https"
    ssl_certificate_name           = "sslCert"
  }

  http_listener {
    name                           = "httpListener"
    frontend_ip_configuration_name = "frontendIpConfig"
    frontend_port_name             = "frontendPortHttp"  # Points to 80
    protocol                       = "Http"
  }

  # --- REDIRECT CONFIGURATION ---
  redirect_configuration {
    name                 = "httpToHttpsRedirect"
    redirect_type        = "Permanent"
    target_listener_name = "httpsListener"
    include_path         = true
    include_query_string = true
  }

  # --- ROUTING RULES ---
  # Rule 1: Handles traffic coming into HTTPS (Port 443) -> Sends to Backend
  request_routing_rule {
    name                       = "routingRuleHttps"
    rule_type                  = "Basic"
    http_listener_name         = "httpsListener" # Changed to look at HTTPS
    backend_address_pool_name  = "backendPool"
    backend_http_settings_name = "backendHttpSettings"
    priority                   = 100
  }

  # Rule 2: Handles traffic coming into HTTP (Port 80) -> Redirects to HTTPS
  request_routing_rule {
    name                        = "routingRuleHttpRedirect"
    rule_type                   = "Basic"
    http_listener_name          = "httpListener" # Looks at HTTP
    redirect_configuration_name = "httpToHttpsRedirect"
    priority                    = 110
  }

  ssl_certificate {
    name                = "sslCert"
    key_vault_secret_id = azurerm_key_vault_certificate.tls_cert.versionless_secret_id
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.appgw_identity.id
    ]
  }

  firewall_policy_id = azurerm_web_application_firewall_policy.waf_policy.id

  depends_on = [azurerm_role_assignment.appgw_kv_reader]
}

resource "azurerm_monitor_diagnostic_setting" "appgw" {
  name                       = "appgw-to-law"
  target_resource_id         = azurerm_application_gateway.appgw.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }
}

# 1. Create the WAF Policy
resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = "example-waf-policy"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  policy_settings {
    enabled = true
    mode    = "Prevention" # Can be "Detection" or "Prevention"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}


resource "azurerm_service_plan" "demo_plan" {
  name                = "My-demo-plan"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "P0v3"
}

resource "azurerm_linux_web_app" "webapp" {
  name                = "miWebapp65748"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.demo_plan.id

  site_config {
    always_on                         = true
    minimum_tls_version               = "1.2"
    ftps_state                        = "Disabled"
    http2_enabled                     = true
    health_check_path                 = "/healthz"
    health_check_eviction_time_in_min = 5
    vnet_route_all_enabled            = true

    application_stack {
      node_version = "24-lts"
    }
    
    app_command_line  = "sh /home/site/wwwroot/startup.sh"
  }


  https_only                                     = true
  public_network_access_enabled                  = false
  virtual_network_subnet_id                      = azurerm_subnet.Spoke_vnet_subnets["WebSubnet"].id
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }
  app_settings = {
    "SCM_DO_BUILD_DURING_DEPLOYMENT"             = "false"
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    "APPLICATIONINSIGHTS_CONNECTION_STRING"      = azurerm_application_insights.appi.connection_string
    "BACKEND_API_URL"                            = "http://${local.app_lb_private_ip}"
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      file_system {
        retention_in_days = 30
        retention_in_mb   = 100
      }
    }
  }
}

resource "azurerm_lb" "lb" {
  name                = "my-lb"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "internalIPfrontend"
    subnet_id                     = azurerm_subnet.Spoke_vnet_subnets["AppSubnet"].id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.app_lb_private_ip
  }
}

resource "azurerm_lb_backend_address_pool" "pool" {
  name            = "vmss-backend-pool"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "http" {
  name                = "http-probe"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Http"
  port                = 3000
  request_path        = "/api/health"
  interval_in_seconds = 10
  number_of_probes    = 3
}

resource "azurerm_lb_rule" "http" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 3000
  frontend_ip_configuration_name = "internalIPfrontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool.id]
  probe_id                       = azurerm_lb_probe.http.id
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "demo-vmss"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Standard_B2s"
  instances           = 1
  admin_username      = "adminuser"
  upgrade_mode        = "Rolling"
  health_probe_id     = azurerm_lb_probe.http.id

  admin_ssh_key {
    username   = "adminuser"
    public_key = var.vmss_public_key
  }
  rolling_upgrade_policy {
    max_batch_instance_percent              = 20
    max_unhealthy_instance_percent          = 20
    max_unhealthy_upgraded_instance_percent = 5
    pause_time_between_batches              = "PT1M"
  }

  identity {
    type = "SystemAssigned"
  }

  extension {
    name                       = "AADSSHLoginForLinux"
    publisher                  = "Microsoft.Azure.ActiveDirectory"
    type                       = "AADSSHLoginForLinux"
    type_handler_version       = "1.0"
    auto_upgrade_minor_version = true
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  encryption_at_host_enabled = true

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "demo-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.Spoke_vnet_subnets["AppSubnet"].id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.pool.id]
    }
  }

  # Read and Base64-encode your cloud-init.yml file
  custom_data = filebase64("${path.module}/../../cloud-init.yaml")

  depends_on = [
    azurerm_lb_rule.http,
    azurerm_firewall.firewall,
    azurerm_firewall_application_rule_collection.fwrc
  ]
}

resource "azurerm_monitor_autoscale_setting" "vmss_autoscale" {
  name                = "myAutoscaleSetting"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.vmss.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  predictive {
    scale_mode      = "Enabled"
    look_ahead_time = "PT5M"
  }
}


resource "azurerm_mssql_server" "sql_server" {
  name                          = "demosqlserver0978432"
  resource_group_name           = data.azurerm_resource_group.rg.name
  location                      = "swedencentral"
  version                       = "12.0"
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"


  azuread_administrator {
    login_username              = "SqlAdmin"
    object_id                   = var.object_id #Object ID of an Entra ID User or Group
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = true
  }

  identity {
    type = "SystemAssigned"
  }

  outbound_network_restriction_enabled = true

  express_vulnerability_assessment_enabled = true
}


resource "azurerm_mssql_database" "sql_database" {
  name                                = "demo_sql_database7893"
  server_id                           = azurerm_mssql_server.sql_server.id
  collation                           = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb                         = 5
  sku_name                            = "S0"
  enclave_type                        = "VBS"
  transparent_data_encryption_enabled = true
}

resource "azurerm_mssql_server_extended_auditing_policy" "demo" {
  server_id              = azurerm_mssql_server.sql_server.id
  log_monitoring_enabled = true
}

resource "azurerm_mssql_database_extended_auditing_policy" "demo" {
  database_id            = azurerm_mssql_database.sql_database.id
  log_monitoring_enabled = true
}
resource "azurerm_monitor_diagnostic_setting" "demo" {
  name                       = "demo-diagnostic-setting"
  target_resource_id         = azurerm_mssql_database.sql_database.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_role_assignment" "appgw_kv_reader" {
  scope                = data.azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_user_assigned_identity.appgw_identity.principal_id
}

resource "azurerm_key_vault_certificate" "tls_cert" {
  name         = "appgw-tls-cert"
  key_vault_id = data.azurerm_key_vault.kv.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=${azurerm_public_ip.public_ip["AppGateway"].fqdn}"
      validity_in_months = 12

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment"
      ]
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"] # serverAuth

      subject_alternative_names {
        dns_names = [azurerm_public_ip.public_ip["AppGateway"].fqdn]
      }
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        lifetime_percentage = 80
      }
    }
  }
}



output "appgw_public_ip" {
  value = azurerm_public_ip.public_ip["AppGateway"].ip_address
}

output "appgw_fqdn" {
  value = azurerm_public_ip.public_ip["AppGateway"].fqdn
}

output "https_url" {
  description = "Browse here (expect a certificate warning, the cert is self-signed)"
  value       = "https://${azurerm_public_ip.public_ip["AppGateway"].fqdn}"
}

output "webapp_default_hostname" {
  value = azurerm_linux_web_app.webapp.default_hostname
}