output "private_dns_zone_ids" {
  description = "Private DNS zone IDs by key."
  value       = { for k, z in azurerm_private_dns_zone.private_dns_zone : k => z.id }
}

output "private_endpoint_ids" {
  description = "Private endpoint IDs by key."
  value       = { for k, e in azurerm_private_endpoint.private_endpoint : k => e.id }
}
