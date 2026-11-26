output "initiative_id" {
  description = "ID of the custom security baseline initiative."
  value       = azurerm_policy_set_definition.baseline.id
}

output "assignment_id" {
  description = "ID of the baseline policy assignment."
  value       = azurerm_resource_group_policy_assignment.baseline.id
}
