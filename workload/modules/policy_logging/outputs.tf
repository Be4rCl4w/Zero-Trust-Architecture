output "assignment_id" {
  description = "ID of the resource-logging policy assignment."
  value       = azurerm_resource_group_policy_assignment.logging.id
}
