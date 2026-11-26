output "id" {
  description = "Scale set ID."
  value       = azurerm_linux_virtual_machine_scale_set.vmss.id
}

output "principal_id" {
  description = "Principal ID of the scale set's system-assigned identity."
  value       = azurerm_linux_virtual_machine_scale_set.vmss.identity[0].principal_id
}
