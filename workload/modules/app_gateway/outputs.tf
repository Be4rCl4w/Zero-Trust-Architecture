output "id" {
  description = "Application Gateway ID."
  value       = azurerm_application_gateway.appgw.id
}

output "identity_principal_id" {
  description = "Principal ID of the gateway's user-assigned identity."
  value       = azurerm_user_assigned_identity.appgw_identity.principal_id
}
