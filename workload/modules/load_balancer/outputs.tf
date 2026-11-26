output "backend_address_pool_id" {
  description = "Backend pool the VMSS registers with."
  value       = azurerm_lb_backend_address_pool.pool.id
}

output "probe_id" {
  description = "Health probe ID (used by the VMSS rolling upgrade policy)."
  value       = azurerm_lb_probe.http.id
}

output "private_ip_address" {
  description = "Private frontend IP."
  value       = var.app_lb_private_ip
}
