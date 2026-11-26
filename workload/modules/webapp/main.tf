resource "azurerm_application_insights" "appi" {
  name                = var.app_insights_name
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = var.log_analytics_workspace_id
}

resource "azurerm_service_plan" "demo_plan" {
  name                = var.service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.service_plan_sku
}

resource "azurerm_linux_web_app" "webapp" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.demo_plan.id

  site_config {
    always_on                         = true
    minimum_tls_version               = "1.2"
    ftps_state                        = "Disabled"
    http2_enabled                     = true
    health_check_path                 = "/healthz"
    health_check_eviction_time_in_min = 5
    vnet_route_all_enabled            = true

    application_stack {
      node_version = var.node_version
    }
    
    app_command_line  = "sh /home/site/wwwroot/startup.sh"
  }


  https_only                                     = true
  public_network_access_enabled                  = false
  virtual_network_subnet_id                      = var.subnet_id
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }
  app_settings = {
    "SCM_DO_BUILD_DURING_DEPLOYMENT"             = "false"
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    "APPLICATIONINSIGHTS_CONNECTION_STRING"      = azurerm_application_insights.appi.connection_string
    "BACKEND_API_URL"                            = "http://${var.app_lb_private_ip}"
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      file_system {
        retention_in_days = 30
        retention_in_mb   = 100
      }
    }
  }
}
