data "azurerm_policy_set_definition" "all_logs" {
  display_name = "Enable allLogs category group resource logging for supported resources to Log Analytics"
}

resource "azurerm_resource_group_policy_assignment" "logging" {
  name                 = "${var.policy_prefix}-resource-logging"
  resource_group_id    = var.resource_group_id
  policy_definition_id = data.azurerm_policy_set_definition.all_logs.id
  display_name         = "${upper(var.policy_prefix)} Resource logging to Log Analytics"
  description          = "Deploys diagnostic settings (allLogs) to the central Log Analytics workspace."
  enforce              = var.policy_enforce
  location             = var.location

  parameters = jsonencode({
    logAnalytics = { value = var.log_analytics_workspace_id }
  })

  identity {
    type = "SystemAssigned"
  }
}

# DeployIfNotExists needs rights to create diagnostic settings
resource "azurerm_role_assignment" "logging_monitoring_contributor" {
  scope                = var.resource_group_id
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.logging.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "logging_law_contributor" {
  scope                = var.log_analytics_workspace_id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.logging.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
