output "id" {
  description = "Web app resource ID."
  value       = azurerm_linux_web_app.webapp.id
}

output "default_hostname" {
  description = "Default hostname of the web app."
  value       = azurerm_linux_web_app.webapp.default_hostname
}

output "principal_id" {
  description = "Principal ID of the web app's system-assigned identity."
  value       = azurerm_linux_web_app.webapp.identity[0].principal_id
}
