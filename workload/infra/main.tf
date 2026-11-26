locals {
  rg_name  = data.azurerm_resource_group.rg.name
  location = data.azurerm_resource_group.rg.location

  # Static private frontend IP of the internal load balancer (10th host of AppSubnet)
  app_lb_private_ip = cidrhost(module.network.spoke_subnets["AppSubnet"].address_prefixes[0], 10)
}

############################################
# Subnets + public IPs
############################################
module "network" {
  source = "../modules/network"

  resource_group_name = local.rg_name
  location            = local.location
  hub_vnet_name       = data.azurerm_virtual_network.Hub_vnet.name
  spoke_vnet_name     = data.azurerm_virtual_network.Spoke_vnet.name
  app_gw_dns_prefix   = "zero-trust-voteapp"
}

############################################
# Azure Firewall (policy-based) + forced-tunnel route table
############################################
module "firewall" {
  source = "../modules/firewall"

  resource_group_name = local.rg_name
  location            = local.location
  firewall_subnet_id  = data.azurerm_subnet.firewall.id
  public_ip_id        = module.network.public_ips["AzureFirewall"].id
  aca_subnet_id       = data.azurerm_subnet.aca.id
  spoke_subnet_ids    = { for k, s in module.network.spoke_subnets : k => s.id }
}

############################################
# Azure Bastion (admin access to the app tier)
############################################
module "bastion" {
  source = "../modules/bastion"

  resource_group_name = local.rg_name
  location            = local.location
  subnet_id           = module.network.hub_subnets["AzureBastionSubnet"].id
  public_ip_id        = module.network.public_ips["AzureBastion"].id
}

############################################
# NSGs (appgw / web / app / db / infra-pe / web-pe)
############################################
module "nsg" {
  source = "../modules/nsg"

  resource_group_name         = local.rg_name
  location                    = local.location
  hub_subnets                 = module.network.hub_subnets
  spoke_subnets               = module.network.spoke_subnets
  aca_subnet_address_prefixes = data.azurerm_subnet.aca.address_prefixes
  app_lb_private_ip           = local.app_lb_private_ip
}

############################################
# Web app (+ App Insights)
############################################
module "webapp" {
  source = "../modules/webapp"

  resource_group_name        = local.rg_name
  location                   = local.location
  name                       = "miWebapp65748"
  subnet_id                  = module.network.spoke_subnets["WebSubnet"].id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
  app_lb_private_ip          = local.app_lb_private_ip
}

############################################
# Application Gateway (WAF v2) + TLS cert
############################################
module "app_gateway" {
  source = "../modules/app_gateway"

  resource_group_name        = local.rg_name
  location                   = local.location
  subnet_id                  = module.network.hub_subnets["AppGatewaySubnet"].id
  public_ip_id               = module.network.public_ips["AppGateway"].id
  public_ip_fqdn             = module.network.public_ips["AppGateway"].fqdn
  key_vault_id               = data.azurerm_key_vault.kv.id
  backend_fqdn               = module.webapp.default_hostname
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
}

############################################
# Internal load balancer in front of the VMSS
############################################
module "load_balancer" {
  source = "../modules/load_balancer"

  resource_group_name = local.rg_name
  location            = local.location
  subnet_id           = module.network.spoke_subnets["AppSubnet"].id
  app_lb_private_ip   = local.app_lb_private_ip
}

############################################
# VMSS behind the internal load balancer
############################################
module "vmss" {
  source = "../modules/vmss"

  resource_group_name        = local.rg_name
  location                   = local.location
  subnet_id                  = module.network.spoke_subnets["AppSubnet"].id
  lb_backend_address_pool_id = module.load_balancer.backend_address_pool_id
  lb_probe_id                = module.load_balancer.probe_id
  admin_ssh_public_key       = var.vmss_public_key

  # NOTE: resolved relative to this directory, exactly as in the original file.
  # Adjust if cloud-init.yaml lives elsewhere relative to infra/.
  custom_data = filebase64("${path.module}/../../cloud-init.yaml")

  # Instances bootstrap through the firewall (apt/npm), so the firewall, its
  # rules and the route table associations must exist first; same for the LB rule.
  depends_on = [module.firewall, module.load_balancer]
}

############################################
# SQL server + database
############################################
module "sql" {
  source = "../modules/sql"

  resource_group_name        = local.rg_name
  location                   = "swedencentral"
  server_name                = "demosqlserver0978432"
  database_name              = "demo_sql_database7893"
  entra_admin_object_id      = var.object_id
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
}

############################################
# Private endpoints + private DNS
############################################
module "private_endpoints" {
  source = "../modules/private_endpoints"

  resource_group_name = local.rg_name
  location            = local.location

  vnets = {
    hub   = data.azurerm_virtual_network.Hub_vnet.id
    spoke = data.azurerm_virtual_network.Spoke_vnet.id
  }

  endpoints = {
    sql = {
      dns_key     = "sql"
      resource_id = module.sql.server_id
      subresource = "sqlServer"
      subnet_id   = module.network.spoke_subnets["DataSubnet"].id
    }
    kv = {
      dns_key     = "kv"
      resource_id = data.azurerm_key_vault.kv.id
      subresource = "vault"
      subnet_id   = module.network.spoke_subnets["WebEndpointSubnet"].id
    }
    webapp = {
      dns_key     = "webapp"
      resource_id = module.webapp.id
      subresource = "sites"
      subnet_id   = module.network.spoke_subnets["WebEndpointSubnet"].id
    }
    acr = {
      dns_key     = "acr"
      resource_id = data.azurerm_container_registry.acr.id
      subresource = "registry"
      subnet_id   = module.network.spoke_subnets["InfraPrivateEndpointsSubnet"].id
    }
  }
}
