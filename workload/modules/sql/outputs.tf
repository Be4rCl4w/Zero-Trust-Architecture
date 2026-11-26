output "server_id" {
  description = "SQL server ID."
  value       = azurerm_mssql_server.sql_server.id
}

output "database_id" {
  description = "SQL database ID."
  value       = azurerm_mssql_database.sql_database.id
}
