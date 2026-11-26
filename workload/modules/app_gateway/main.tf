resource "azurerm_user_assigned_identity" "appgw_identity" {
  name                = var.identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "appgw_kv_reader" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_user_assigned_identity.appgw_identity.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_key_vault_certificate" "tls_cert" {
  name         = var.certificate_name
  key_vault_id = var.key_vault_id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=${var.public_ip_fqdn}"
      validity_in_months = 12

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment"
      ]
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"] # serverAuth

      subject_alternative_names {
        dns_names = [var.public_ip_fqdn]
      }
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        lifetime_percentage = 80
      }
    }
  }
  depends_on = [
    azurerm_role_assignment.appgw_kv_reader
  ]
}

resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = var.waf_policy_name
  resource_group_name = var.resource_group_name
  location            = var.location

  policy_settings {
    enabled = true
    mode    = "Prevention" # Can be "Detection" or "Prevention"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

resource "azurerm_application_gateway" "appgw" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = var.subnet_id
  }

  # --- FRONTEND PORTS ---
  frontend_port {
    name = "frontendPortHttps" # Split into unique names
    port = 443
  }

  frontend_port {
    name = "frontendPortHttp"  # Added distinct port 80 for HTTP
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontendIpConfig"
    public_ip_address_id = var.public_ip_id
  }

  backend_address_pool {
    name = "backendPool"
    fqdns = [var.backend_fqdn]
  }

  probe {
    name                                      = "demo-probe"
    protocol                                  = "Https"
    path                                      = "/healthz"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-399"]
    }
  }

  backend_http_settings {
    name                                = "backendHttpSettings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
    probe_name                          = "demo-probe"
  }

  # --- LISTENERS ---
  http_listener {
    name                           = "httpsListener"
    frontend_ip_configuration_name = "frontendIpConfig"
    frontend_port_name             = "frontendPortHttps" # Points to 443
    protocol                       = "Https"
    ssl_certificate_name           = "sslCert"
  }

  http_listener {
    name                           = "httpListener"
    frontend_ip_configuration_name = "frontendIpConfig"
    frontend_port_name             = "frontendPortHttp"  # Points to 80
    protocol                       = "Http"
  }

  # --- REDIRECT CONFIGURATION ---
  redirect_configuration {
    name                 = "httpToHttpsRedirect"
    redirect_type        = "Permanent"
    target_listener_name = "httpsListener"
    include_path         = true
    include_query_string = true
  }

  # --- ROUTING RULES ---
  # Rule 1: Handles traffic coming into HTTPS (Port 443) -> Sends to Backend
  request_routing_rule {
    name                       = "routingRuleHttps"
    rule_type                  = "Basic"
    http_listener_name         = "httpsListener" # Changed to look at HTTPS
    backend_address_pool_name  = "backendPool"
    backend_http_settings_name = "backendHttpSettings"
    priority                   = 100
  }

  # Rule 2: Handles traffic coming into HTTP (Port 80) -> Redirects to HTTPS
  request_routing_rule {
    name                        = "routingRuleHttpRedirect"
    rule_type                   = "Basic"
    http_listener_name          = "httpListener" # Looks at HTTP
    redirect_configuration_name = "httpToHttpsRedirect"
    priority                    = 110
  }

  ssl_certificate {
    name                = "sslCert"
    key_vault_secret_id = azurerm_key_vault_certificate.tls_cert.versionless_secret_id
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.appgw_identity.id
    ]
  }

  firewall_policy_id = azurerm_web_application_firewall_policy.waf_policy.id

  depends_on = [
    azurerm_role_assignment.appgw_kv_reader,
    azurerm_key_vault_certificate.tls_cert
  ]
}

resource "azurerm_monitor_diagnostic_setting" "appgw" {
  name                       = var.diagnostic_setting_name
  target_resource_id         = azurerm_application_gateway.appgw.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }
}
