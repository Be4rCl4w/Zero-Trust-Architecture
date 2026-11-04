terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">=4.81.0"
    }

    azuread = {
      source = "hashicorp/azuread"
      version = ">=3.5.0"
    }
  }
}

provider "azuread" {}
provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "primary" {}

data "azurerm_log_analytics_workspace" "law" {
  name                = "DefaultWorkspace-0af19ed5-487a-47e1-bc21-11f4ae6bc5a8-NEU"
  resource_group_name = "defaultresourcegroup-neu"
}

locals {
  resource_groups = [
    "rg-tfstate",
    "Demo-RG1"
  ]
}

resource "azurerm_resource_group" "rg" {
  for_each = toset(local.resource_groups)
  name     = each.value
  location = "North Europe"
}

resource "azurerm_role_definition" "enterprise_iac_role" {
  name        = "Enterprise IaC Deployment Role"
  scope       = data.azurerm_subscription.primary.id
  description = "Least-privilege custom role for Terraform/CI/CD pipelines to provision core infrastructure, excluding authorization and role assignment capabilities."

  # Actions allowed across core resource providers
  permissions {
    actions = [
      "Microsoft.Resources/deployments/*",
      "Microsoft.Resources/subscriptions/resourceGroups/*",
      "Microsoft.ManagedIdentity/*",
      "Microsoft.Compute/*",
      "Microsoft.Network/*",
      "Microsoft.Storage/*",
      "Microsoft.Web/*",
      "Microsoft.KeyVault/*",
      "Microsoft.ContainerService/*",
      "Microsoft.ContainerRegistry/*",
      "Microsoft.Sql/*",
      "Microsoft.DocumentDB/*",
      "Microsoft.Cache/*",
      "Microsoft.DBforPostgreSQL/*",
      "Microsoft.DBforMySQL/*"
    ]
    not_actions = [
      "Microsoft.Authorization/*"
    ]
    data_actions     = []
    not_data_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.primary.id
  ]
}

resource "azuread_application" "github_deploy" {
  display_name = "gh-deploy"
}

resource "azuread_service_principal" "github_deploy" {
  client_id = azuread_application.github_deploy.client_id
}

resource "azurerm_role_assignment" "deployer_cert_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = azuread_service_principal.github_deploy.object_id

   depends_on = [azurerm_key_vault.kv]
}

resource "azurerm_role_assignment" "contributor" {
  scope                            = data.azurerm_subscription.primary.id
  role_definition_name             = azurerm_role_definition.enterprise_iac_role.name
  principal_id                     = azuread_service_principal.github_deploy.object_id
  skip_service_principal_aad_check = true

}

resource "azurerm_role_assignment" "delegated_cicd_assignment" {
  scope                            = data.azurerm_subscription.primary.id
  role_definition_name             = "Role Based Access Control Administrator"
  principal_id                     = azuread_service_principal.github_deploy.object_id
  skip_service_principal_aad_check = true

  condition_version = "2.0"

  # This condition restricts the pipeline to assigning ONLY specific, 
  # pre-approved data and runtime roles to Service Principals. (Storage Blob Data Contributor, Key Vault Secrets User,Key Vault Crypto User,Key Vault Certificate User, AcrPull, Monitoring Metrics Publisher)
  condition = <<EOF
(
  !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
  OR
  (
    @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {ba92f5b4-2d11-453d-a403-e96b0029c9fe, 4633458b-17de-408a-b874-0445c86b69e6, 12338af0-0e69-4050-8b5d-48842dcc471d, 00482a5a-887f-4fb3-b363-3b7fe8e74483, 7f951dda-4ed3-4680-a7ca-43fe172d538d, 3913510d-42f4-4e42-8a64-42c3c92534ca}
    AND
    @Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
  )
)
EOF
}

resource "azurerm_role_assignment" "data_contributor" {
  scope                = azurerm_resource_group.rg["rg-tfstate"].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.github_deploy.object_id
}

resource "azurerm_role_assignment" "user_contributor" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "User Access Administrator"
  principal_id         = azuread_service_principal.github_deploy.object_id

  depends_on = [azurerm_key_vault.kv]
}

resource "azurerm_role_assignment" "deployer_kv_officer" {
  scope                = azurerm_resource_group.rg["Demo-RG1"].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id

  depends_on = [azurerm_key_vault.kv]
}

resource "azurerm_role_assignment" "vmss_admin_login" {
  scope                = azurerm_resource_group.rg["Demo-RG1"].id
  role_definition_name = "Virtual Machine Administrator Login"  # sudo
  principal_id         = data.azurerm_client_config.current.object_id  # Better to use Group object ID  
}

resource "azurerm_user_assigned_identity" "runner" {
  name                = "id-${var.prefix}"
  location            = azurerm_resource_group.rg["Demo-RG1"].location
  resource_group_name = azurerm_resource_group.rg["Demo-RG1"].name
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.runner.principal_id

  depends_on = [azurerm_container_registry.acr]
}

resource "azurerm_role_assignment" "secret_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.runner.principal_id

  depends_on = [azurerm_key_vault.kv, azurerm_key_vault_secret.github_pat_token]
}


resource "azuread_application_federated_identity_credential" "github_branch" {
  application_id = azuread_application.github_deploy.id
  display_name   = "github-prod-environment"
  description    = "Federated credential for GitHub Actions locked to the production environment."
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:Be4rCl4w@121987346/Zero-Trust-Architecture@1430910856:environment:production"
}

resource "azurerm_storage_account" "tfstate" {
  name                = "sttfstate1unique123"
  resource_group_name = azurerm_resource_group.rg["rg-tfstate"].name
  location            = azurerm_resource_group.rg["rg-tfstate"].location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  shared_access_key_enabled = false
  default_to_oauth_authentication = true

  allow_nested_items_to_be_public = false
  min_tls_version                  = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

resource "azurerm_virtual_network" "Hub_vnet" {
  resource_group_name = azurerm_resource_group.rg["Demo-RG1"].name
  location            = azurerm_resource_group.rg["Demo-RG1"].location
  name                = "Hub_demo_vnet"
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_virtual_network" "Spoke_vnet" {
  resource_group_name = azurerm_resource_group.rg["Demo-RG1"].name
  location            = azurerm_resource_group.rg["Demo-RG1"].location
  name                = "Spoke_demo_vnet"
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "aca" {
  name                 = "ACA-JobSubnet"
  resource_group_name  = azurerm_resource_group.rg["Demo-RG1"].name
  virtual_network_name = azurerm_virtual_network.Hub_vnet.name
  address_prefixes     = ["10.0.3.0/26"]

  delegation {
    name = "aca"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_network_security_group" "github_runner" {
  name                = "Demo-github-runner-nsg"
  location            = azurerm_resource_group.rg["Demo-RG1"].location
  resource_group_name = azurerm_resource_group.rg["Demo-RG1"].name


  security_rule {
    name                       = "github-runner-in-deny-all"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit deny all inbound"
  }

  security_rule {
    name                       = "github-runner-outbound-allow"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Explicit allow all outbound"
  }
}

resource "azurerm_subnet_network_security_group_association" "github_runner" {
  subnet_id                 = azurerm_subnet.aca.id
  network_security_group_id = azurerm_network_security_group.github_runner.id
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-spoke-to-hub"
  resource_group_name       = azurerm_resource_group.rg["Demo-RG1"].name
  virtual_network_name      = azurerm_virtual_network.Spoke_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.Hub_vnet.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false

}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-spoke"
  resource_group_name       = azurerm_resource_group.rg["Demo-RG1"].name
  virtual_network_name      = azurerm_virtual_network.Hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.Spoke_vnet.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
  use_remote_gateways       = false
}

resource "azurerm_key_vault" "kv" {
  name                      = "Deemo-kv213"
  location                  = azurerm_resource_group.rg["Demo-RG1"].location
  resource_group_name       = azurerm_resource_group.rg["Demo-RG1"].name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  rbac_authorization_enabled  = true 
  public_network_access_enabled = true
}

# 3. GitHub App Private Key Secret
resource "azurerm_key_vault_secret" "github_pat_token" {
  name             = "github-pat-token"
  value            = var.github_pat_token
  key_vault_id     = azurerm_key_vault.kv.id

  #content_type = "application/x-pem-file"

  depends_on = [azurerm_key_vault.kv, azurerm_role_assignment.deployer_kv_officer]
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diag-${azurerm_key_vault.kv.name}"
  target_resource_id         = azurerm_key_vault.kv.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# ---------- Registry + identity ----------
resource "azurerm_container_registry" "acr" {
  name                          = "myghrunneracr123"
  resource_group_name           = azurerm_resource_group.rg["Demo-RG1"].name
  location                      = azurerm_resource_group.rg["Demo-RG1"].location
  sku                           = "Standard"
  admin_enabled                 = false
  #public_network_access_enabled = false
  anonymous_pull_enabled        = false
}


resource "terraform_data" "build_image" {
  provisioner "local-exec" {
    # Ensure your local execution context is authenticated via Azure CLI (az login) before running
    command = "az acr build --registry ${azurerm_container_registry.acr.name} --image gh-runner:v1.0 ."

    working_dir = "${path.module}/../../"
  }

  depends_on = [azurerm_container_registry.acr]
}


# ---------- Container Apps environment (in your VNet) ----------
resource "azurerm_container_app_environment" "env" {
  name                       = "cae-${var.prefix}"
  location                   = azurerm_resource_group.rg["Demo-RG1"].location
  resource_group_name        = azurerm_resource_group.rg["Demo-RG1"].name
  logs_destination           = "log-analytics" 
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
  infrastructure_subnet_id   = azurerm_subnet.aca.id
  internal_load_balancer_enabled = false
  public_network_access      = "Disabled"

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

# ---------- The event-driven job ----------
resource "azurerm_container_app_job" "runner" {
  name                         = "caj-${var.prefix}"
  location                     = azurerm_resource_group.rg["Demo-RG1"].location
  resource_group_name          = azurerm_resource_group.rg["Demo-RG1"].name
  container_app_environment_id = azurerm_container_app_environment.env.id
  workload_profile_name        = "Consumption"

  replica_timeout_in_seconds = 1800  # max job runtime (incl. idle wait for a job)
  replica_retry_limit        = 0

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.runner.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.runner.id
  }

  secret {
    name                = "github-app-key"
    identity            = azurerm_user_assigned_identity.runner.id
    key_vault_secret_id = azurerm_key_vault_secret.github_pat_token.versionless_id
  }

  event_trigger_config {
    parallelism              = 1
    replica_completion_count = 1

    scale {
      min_executions              = 0
      max_executions              = var.max_runners
      polling_interval_in_seconds = 30

      rules {
        name             = "github-runner"
        custom_rule_type = "github-runner"

        metadata = {
          githubAPIURL              = "https://api.github.com"
          owner                     = var.github_owner
          runnerScope               = var.github_runner_scope
          repos                     = var.github_repo   # ignored for org scope
          labels                    = var.runner_labels
          targetWorkflowQueueLength = "1"
          #applicationID             = var.github_app_id
          #installationID            = var.github_app_installation_id
          enableEtags               = "true"
        }

        authentication {
          secret_name       = "github-pat-token"
          trigger_parameter = "personalAccessToken"
        }
        identity_id = azurerm_user_assigned_identity.runner.id
      }
    }
  }

  template {
    container {
      name   = "runner"
      image  = "${azurerm_container_registry.acr.login_server}/gh-runner:v1.0"
      cpu    = "0.25"    
      memory = "0.5Gi"

      env {
        name  = "GITHUB_OWNER"
        value = var.github_owner
      }
      env {
        name  = "GITHUB_REPO"
        value = var.github_repo
      }
      env {
        name  = "RUNNER_SCOPE"
        value = var.github_runner_scope
      }
      env {
        name  = "RUNNER_LABELS"
        value = var.runner_labels
      }
      env {
        name = "GH_URL"
        value = var.gh_url
      }
      env {
        name = "REGISTRATION_TOKEN_API_URL"
        value = var.reg_token_url
      }
      #env {
        #name  = "GITHUB_APP_ID"
        #value = var.github_app_id
      #}
      #env {
        #name  = "GITHUB_APP_INSTALLATION_ID"
        #value = var.github_app_installation_id
      #}
      env {
        name        = "GITHUB_PAT_TOKEN"
        secret_name = "github-pat-token"
      }
    }
  }
  lifecycle {
    ignore_changes = [
      template[0].container[0].image
    ]
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_key_vault_secret.github_pat_token,
    terraform_data.build_image
  ]
  
}


locals {
  Hub_subnets = {
    "AzureBastionSubnet"  = "10.0.1.0/27"
    "AzureFirewallSubnet" = "10.0.0.0/26"
    "AppGatewaySubnet"    = "10.0.2.0/26"
  }
}

locals {
  Spoke_subnets = {
    "WebSubnet" = {
      address_prefix = "10.20.0.0/24"
      delegate       = true # delegation
    }
    "AppSubnet" = {
      address_prefix = "10.20.1.0/24"
      delegate       = false # No delegation
    }
    "DataSubnet" = {
      address_prefix = "10.20.3.0/24"
      delegate       = false # No delegation
    }
    "PrivateEndpointSubnet" = {
      address_prefix = "10.20.4.0/24"
      delegate       = false # No delegation
    }
  }
}

resource "azurerm_subnet" "Spoke_vnet_subnets" {
  for_each             = local.Spoke_subnets
  name                 = each.key
  resource_group_name  = azurerm_resource_group.rg["Demo-RG1"].name
  virtual_network_name = azurerm_virtual_network.Spoke_vnet.name
  address_prefixes     = [each.value.address_prefix]

  # Conditionally add delegation block using dynamic
  dynamic "delegation" {
    for_each = each.value.delegate ? [1] : []

    content {
      name = "app-service-delegation"

      service_delegation {
        name    = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
  }
}

resource "azurerm_subnet" "Hub_vnet_subnets" {
  for_each             = local.Hub_subnets
  name                 = each.key
  resource_group_name  = azurerm_resource_group.rg["Demo-RG1"].name
  virtual_network_name = azurerm_virtual_network.Hub_vnet.name
  address_prefixes     = [each.value]
}
