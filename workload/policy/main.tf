module "policy_baseline" {
  source = "../modules/policy_baseline"

  policy_prefix       = var.policy_prefix
  policy_enforce      = var.policy_enforce
  allowed_locations   = var.allowed_locations
  required_tags       = var.required_tags
  resource_group_id   = data.azurerm_resource_group.rg.id
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  firewall_subnet_id  = data.azurerm_subnet.fw.id
}

module "policy_logging" {
  source = "../modules/policy_logging"

  policy_prefix              = var.policy_prefix
  policy_enforce             = var.policy_enforce
  resource_group_id          = data.azurerm_resource_group.rg.id
  location                   = data.azurerm_resource_group.rg.location
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
}
