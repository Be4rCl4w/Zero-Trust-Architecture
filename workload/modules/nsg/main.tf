############################################
# App Gateway NSG
############################################
resource "azurerm_network_security_group" "appgw" {
  name                = "Demo-appGW-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

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
    destination_port_ranges      = ["80", "443"]
    source_address_prefixes      = var.hub_subnets["AppGatewaySubnet"].address_prefixes
    destination_address_prefixes = var.spoke_subnets["WebEndpointSubnet"].address_prefixes
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
    source_address_prefixes      = var.hub_subnets["AppGatewaySubnet"].address_prefixes
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
    source_address_prefixes      = var.hub_subnets["AppGatewaySubnet"].address_prefixes
    destination_address_prefixes = var.spoke_subnets["WebEndpointSubnet"].address_prefixes
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
  location            = var.location
  resource_group_name = var.resource_group_name

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
    source_address_prefixes    = var.spoke_subnets["WebSubnet"].address_prefixes
    destination_address_prefix = var.app_lb_private_ip
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
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                         = "app-in-from-web"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_ranges      = ["3000", "80", "443"]
    source_address_prefixes      = var.spoke_subnets["WebSubnet"].address_prefixes
    destination_address_prefixes = var.spoke_subnets["AppSubnet"].address_prefixes
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
    destination_address_prefixes = var.spoke_subnets["AppSubnet"].address_prefixes
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
    source_address_prefixes      = var.hub_subnets["AzureBastionSubnet"].address_prefixes
    destination_address_prefixes = var.spoke_subnets["AppSubnet"].address_prefixes
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
    source_address_prefixes      = var.aca_subnet_address_prefixes
    destination_address_prefixes = var.spoke_subnets["AppSubnet"].address_prefixes
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
    source_address_prefixes      = var.spoke_subnets["AppSubnet"].address_prefixes
    destination_address_prefixes = var.spoke_subnets["DataSubnet"].address_prefixes
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
    source_address_prefixes      = var.spoke_subnets["AppSubnet"].address_prefixes
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
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                         = "db-in-from-app"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "1433"
    source_address_prefixes      = var.spoke_subnets["AppSubnet"].address_prefixes
    destination_address_prefixes = var.spoke_subnets["DataSubnet"].address_prefixes
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
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                         = "PE-in-from-ACA"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefixes      = var.aca_subnet_address_prefixes
    destination_address_prefixes = var.spoke_subnets["InfraPrivateEndpointsSubnet"].address_prefixes
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
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                         = "PE-in-from-appGW"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefixes      = var.hub_subnets["AppGatewaySubnet"].address_prefixes
    destination_address_prefixes = var.spoke_subnets["WebEndpointSubnet"].address_prefixes
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
    source_address_prefixes      = var.aca_subnet_address_prefixes
    destination_address_prefixes = var.spoke_subnets["WebEndpointSubnet"].address_prefixes
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
  subnet_id                 = var.hub_subnets["AppGatewaySubnet"].id
  network_security_group_id = azurerm_network_security_group.appgw.id
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = var.spoke_subnets["WebSubnet"].id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = var.spoke_subnets["AppSubnet"].id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = var.spoke_subnets["DataSubnet"].id
  network_security_group_id = azurerm_network_security_group.db.id
}

resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = var.spoke_subnets["InfraPrivateEndpointsSubnet"].id
  network_security_group_id = azurerm_network_security_group.pe.id
}

resource "azurerm_subnet_network_security_group_association" "web-pe" {
  subnet_id                 = var.spoke_subnets["WebEndpointSubnet"].id
  network_security_group_id = azurerm_network_security_group.web-pe.id
}

