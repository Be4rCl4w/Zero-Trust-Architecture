# Existing resources this stack builds on.

data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "law" {
  name                = "DefaultWorkspace-0af19ed5-487a-47e1-bc21-11f4ae6bc5a8-NEU"
  resource_group_name = "defaultresourcegroup-neu"
}

data "azurerm_resource_group" "rg" {
  name = "Demo-RG1"
}

data "azurerm_virtual_network" "Hub_vnet" {
  name                = "Hub_demo_vnet"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_virtual_network" "Spoke_vnet" {
  name                = "Spoke_demo_vnet"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_subnet" "aca" {
  name                 = "ACA-JobSubnet"
  virtual_network_name = data.azurerm_virtual_network.Hub_vnet.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

data "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  virtual_network_name = data.azurerm_virtual_network.Hub_vnet.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

data "azurerm_container_registry" "acr" {
  name                = "myghrunneracr123"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_key_vault" "kv" {
  name                = "Deemo-kv213"
  resource_group_name = data.azurerm_resource_group.rg.name
}
