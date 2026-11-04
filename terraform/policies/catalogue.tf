terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.81.0"
    }
  }
}

provider "azurerm" {
  features {}
}


data "azurerm_log_analytics_workspace" "law" {
  name                = "DefaultWorkspace-0af19ed5-487a-47e1-bc21-11f4ae6bc5a8-NEU"
  resource_group_name = "defaultresourcegroup-neu"
}

data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = "Demo-RG1"
}

data "azurerm_virtual_network" "Hub_vnet" {
  name                = "Hub_demo_vnet"
  resource_group_name = "Demo-RG1"
}

data "azurerm_subnet" "fw" {
  name                 = "AzureFirewallSubnet"
  virtual_network_name = "Hub_demo_vnet"
  resource_group_name  = "Demo-RG1"
}

############################################
# 1. Policy catalogue 
############################################
locals {
  baseline_static = {
    # 1. Allowed locations
    allowed_locations = {
      name       = "e56962a6-4747-49cd-b67b-bf8b01975c4c"
      parameters = { listOfAllowedLocations = var.allowed_locations, effect = "Deny" }
    }

    # 3. WAF
    waf_enabled = {
      name       = "564feb30-bf6a-4854-b4bb-0d2d2d1e6c66"
      parameters = { effect = "Deny" }
    }
    waf_mode = {
      name       = "12430be1-6cc8-4527-a9a8-e3d38f250096"
      parameters = { effect = "Deny", modeRequirement = "Prevention" }
    }

    # 4. SQL authentication and network
    sql_entra_only = {
      name       = "b3a22bc9-66de-45fb-98fa-00f5df42f41a"
      parameters = { effect = "Deny" }
    }
    sql_public_access = {
      name       = "1b8ca024-1d5c-4dec-8995-b1a932b41780"
      parameters = { effect = "Deny" }
    }

    # 5. SQL auditing and vulnerability assessment
    sql_auditing = {
      name       = "a6fb4358-5bf4-4ad7-ba82-2cd2f41ce5e9"
      parameters = { effect = "AuditIfNotExists" }
    }
    sql_va = {
      name       = "ef2a8f2a-b3d9-49cd-a8a8-9a3aaaf647d9"
      parameters = { effect = "AuditIfNotExists" }
    }

    # 6. Key Vault protection
    kv_soft_delete = {
      name       = "1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d"
      parameters = { effect = "Deny" }
    }
    kv_purge_protection = {
      name       = "0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
      parameters = { effect = "Deny" }
    }

    # 7. Key Vault network and RBAC
    kv_public_access = {
      name       = "405c5871-3e91-4644-8a63-58e19d68ff5b"
      parameters = { effect = "Deny" }
    }
    kv_rbac = {
      name       = "12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5"
      parameters = { effect = "Deny" }
    }

    # 8. App Service hardening
    app_https = {
      name       = "a4af4a39-4135-47fb-b175-47fbdf85311d"
      parameters = { effect = "Deny" }
    }
    app_tls = {
      name       = "f0e6e85b-9b9f-4a4b-b67b-f730d42f1b0b"
      parameters = { effect = "AuditIfNotExists" }
    }
    app_public_access = {
      name       = "1b5ef780-c53c-4a64-87f3-bb9c8c8094ba"
      parameters = { effect = "Deny" }
    }

    # 9. App Service identity and logging
    app_managed_identity = {
      name       = "2b9ad585-36bc-4615-b300-fd4435808332"
      parameters = { effect = "AuditIfNotExists" }
    }
    app_resource_logs = {
      name       = "91a78b24-f231-4a8a-8da9-02c35b2b6510"
      parameters = { effect = "AuditIfNotExists" }
    }

    # 10. NSG on subnets
    subnet_nsg = {
      name       = "e71308d3-144b-4262-b144-efdc3cc90517"
      parameters = { effect = "AuditIfNotExists" }
    }

    # 11. VM network exposure
    vm_mgmt_ports = {
      name       = "22730e10-96f6-4aac-ad84-9383d35b5917"
      parameters = { effect = "AuditIfNotExists" }
    }
    nic_no_public_ip = {
      name       = "83a86a26-fd1f-447c-b59d-e51f44264114"
      parameters = {}
    }

    # 12. Container Registry
    acr_network = {
      name       = "d0793b48-0edc-4296-a390-4c75d1bdfd71"
      parameters = { effect = "Deny" }
    }
    acr_admin_disabled = {
      name       = "dc921057-6b28-4fbe-9b83-f7bec05db6c2"
      parameters = { effect = "Deny" }
    }
    acr_private_link = {
      name       = "e8eef0a8-67cf-4eb4-9386-14b0e78733d4"
      parameters = { effect = "Audit" }
    }

    # 13. Container Apps
    aca_public_access = {
      name       = "d074ddf8-01a5-4b5e-a2b8-964aed452c0a"
      parameters = { effect = "Deny" }
    }
    aca_https = {
      name       = "0e80e269-43a4-4ae9-b5bc-178126b8a5cb"
      parameters = { effect = "Deny" }
    }

    # 14. Linux VM / VMSS
    linux_ssh_keys = {
      name       = "630c64f9-8b6b-4c64-b511-6544ceff6fd6"
      parameters = { effect = "AuditIfNotExists" }
    }
    vm_encryption_at_host = {
      name       = "fc4d8e41-e223-45ea-9bf5-eada37891d87"
      parameters = { effect = "Audit" }
    }
  }

  # 2. Tagging (one reference per required tag)
  tag_require = {
    for t in var.required_tags : "require_tag_${t}" => {
      name       = "871b6d14-10aa-478d-b590-94f262ecfa99"
      parameters = { tagName = t }
    }
  }

  tag_inherit = {
    for t in var.required_tags : "inherit_tag_${t}" => {
      name       = "ea3f2387-9b95-492a-a190-fcdc54f7b070"
      parameters = { tagName = t }
    }
  }

  # Unify all maps cleanly inside the same locals block
  baseline_policies = merge(local.baseline_static, local.tag_require, local.tag_inherit)

  # Generate a unique list of Policy IDs instead of fragile string names
  baseline_policy_ids = toset([for v in values(local.baseline_policies) : v.name])
}


############################################
# 2. Look up built-in definitions by display name
############################################
data "azurerm_policy_definition" "builtin" {
  for_each = local.baseline_policies
  name     = each.value.name
}


############################################
# 3. Custom initiative: security baseline
############################################
resource "azurerm_policy_set_definition" "baseline" {
  name         = "${var.policy_prefix}-security-baseline"
  policy_type  = "Custom"
  display_name = "${upper(var.policy_prefix)} Azure Security Baseline"
  description  = "Network, identity, data protection and governance controls for the hub-and-spoke environment."

  metadata = jsonencode({
    category = "Security"
    version  = "1.1.0"
  })

  dynamic "policy_definition_reference" {
    for_each = local.baseline_policies

    content {
      reference_id         = policy_definition_reference.key
      policy_definition_id = data.azurerm_policy_definition.builtin[policy_definition_reference.key].id
      parameter_values = jsonencode({
        for k, v in policy_definition_reference.value.parameters : k => { value = v }
      })
    }
  }
}

############################################
# 4. Baseline assignment (resource group scope)
############################################
resource "azurerm_resource_group_policy_assignment" "baseline" {
  name                 = "${var.policy_prefix}-baseline"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = azurerm_policy_set_definition.baseline.id
  display_name         = "${upper(var.policy_prefix)} Azure Security Baseline"
  description          = "Assigns the security baseline initiative to ${data.azurerm_resource_group.rg.name}."
  enforce              = var.policy_enforce
  location             = data.azurerm_resource_group.rg.location

  identity {
    type = "SystemAssigned"
  }

  non_compliance_message {
    content = "This resource violates the security baseline. See the policy definition for the required configuration."
  }
}

# The Modify effect (tag inheritance) needs Tag Contributor
resource "azurerm_role_assignment" "baseline_tag_contributor" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Tag Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.baseline.identity[0].principal_id
}

############################################
# 5. Exemption: Azure Firewall subnet cannot have an NSG
############################################
resource "azurerm_resource_policy_exemption" "firewall_subnet_nsg" {
  name                            = "azfw-subnet-no-nsg"
  resource_id                     = data.azurerm_subnet.fw.id
  policy_assignment_id            = azurerm_resource_group_policy_assignment.baseline.id
  exemption_category              = "Waiver"
  display_name                    = "AzureFirewallSubnet does not support NSGs"
  description                     = "Azure Firewall subnets cannot be associated with an NSG (platform limitation)."
  policy_definition_reference_ids = ["subnet_nsg"]
}

############################################
# 6. Policy 15: built-in allLogs initiative -> Log Analytics
############################################
data "azurerm_policy_set_definition" "all_logs" {
  display_name = "Enable allLogs category group resource logging for supported resources to Log Analytics"
}

resource "azurerm_resource_group_policy_assignment" "logging" {
  name                 = "${var.policy_prefix}-resource-logging"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_set_definition.all_logs.id
  display_name         = "${upper(var.policy_prefix)} Resource logging to Log Analytics"
  description          = "Deploys diagnostic settings (allLogs) to the central Log Analytics workspace."
  enforce              = var.policy_enforce
  location             = data.azurerm_resource_group.rg.location

  parameters = jsonencode({
    logAnalytics = { value = data.azurerm_log_analytics_workspace.law.id }
  })

  identity {
    type = "SystemAssigned"
  }
}

# DeployIfNotExists needs rights to create diagnostic settings
resource "azurerm_role_assignment" "logging_monitoring_contributor" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.logging.identity[0].principal_id
}

resource "azurerm_role_assignment" "logging_law_contributor" {
  scope                = data.azurerm_log_analytics_workspace.law.id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.logging.identity[0].principal_id
}

############################################
# Outputs
############################################
output "baseline_initiative_id" {
  value = azurerm_policy_set_definition.baseline.id
}

output "baseline_assignment_id" {
  value = azurerm_resource_group_policy_assignment.baseline.id
}