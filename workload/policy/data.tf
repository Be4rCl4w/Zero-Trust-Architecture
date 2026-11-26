# Existing resources this stack builds on.

data "azurerm_log_analytics_workspace" "law" {
  name                = "DefaultWorkspace-0af19ed5-487a-47e1-bc21-11f4ae6bc5a8-NEU"
  resource_group_name = "defaultresourcegroup-neu"
}

data "azurerm_resource_group" "rg" {
  name = "Demo-RG1"
}

data "azurerm_subnet" "fw" {
  name                 = "AzureFirewallSubnet"
  virtual_network_name = "Hub_demo_vnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
}
