resource "azurerm_mssql_server" "sql_server" {
  name                          = var.server_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"


  azuread_administrator {
    login_username              = "SqlAdmin"
    object_id                   = var.entra_admin_object_id #Object ID of an Entra ID User or Group
    tenant_id                   = var.tenant_id
    azuread_authentication_only = true
  }

  identity {
    type = "SystemAssigned"
  }

  outbound_network_restriction_enabled = true

  express_vulnerability_assessment_enabled = true
}

resource "azurerm_mssql_database" "sql_database" {
  name                                = var.database_name
  server_id                           = azurerm_mssql_server.sql_server.id
  collation                           = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb                         = 5
  sku_name                            = "S0"
  enclave_type                        = "VBS"
  transparent_data_encryption_enabled = true
}

resource "azurerm_mssql_server_extended_auditing_policy" "demo" {
  server_id              = azurerm_mssql_server.sql_server.id
  log_monitoring_enabled = true
}

resource "azurerm_mssql_database_extended_auditing_policy" "demo" {
  database_id            = azurerm_mssql_database.sql_database.id
  log_monitoring_enabled = true
}

resource "azurerm_monitor_diagnostic_setting" "demo" {
  name                       = "demo-diagnostic-setting"
  target_resource_id         = azurerm_mssql_database.sql_database.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
