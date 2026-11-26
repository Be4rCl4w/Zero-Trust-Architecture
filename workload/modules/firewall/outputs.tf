output "private_ip_address" {
  description = "Private IP of the firewall."
  value       = azurerm_firewall.firewall.ip_configuration[0].private_ip_address
}

output "route_table_id" {
  description = "ID of the route table that sends 0.0.0.0/0 through the firewall."
  value       = azurerm_route_table.rt.id
}

output "policy_id" {
  description = "ID of the firewall policy."
  value       = azurerm_firewall_policy.policy.id
}
