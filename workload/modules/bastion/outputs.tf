output "id" {
  description = "Bastion host ID."
  value       = azurerm_bastion_host.bastion.id
}

output "dns_name" {
  description = "Bastion host DNS name."
  value       = azurerm_bastion_host.bastion.dns_name
}
