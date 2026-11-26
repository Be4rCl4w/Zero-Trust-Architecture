output "appgw_public_ip" {
  value = module.network.public_ips["AppGateway"].ip_address
}

output "appgw_fqdn" {
  value = module.network.public_ips["AppGateway"].fqdn
}

output "https_url" {
  description = "Browse here (expect a certificate warning, the cert is self-signed)"
  value       = "https://${module.network.public_ips["AppGateway"].fqdn}"
}

output "webapp_default_hostname" {
  value = module.webapp.default_hostname
}
