data "azurerm_policy_definition" "builtin" {
  for_each = local.baseline_policies
  name     = each.value.name
}

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

resource "azurerm_resource_group_policy_assignment" "baseline" {
  name                 = "${var.policy_prefix}-baseline"
  resource_group_id    = var.resource_group_id
  policy_definition_id = azurerm_policy_set_definition.baseline.id
  display_name         = "${upper(var.policy_prefix)} Azure Security Baseline"
  description          = "Assigns the security baseline initiative to ${var.resource_group_name}."
  enforce              = var.policy_enforce
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  non_compliance_message {
    content = "This resource violates the security baseline. See the policy definition for the required configuration."
  }
}

# The Modify effect (tag inheritance) needs Tag Contributor
resource "azurerm_role_assignment" "baseline_tag_contributor" {
  scope                = var.resource_group_id
  role_definition_name = "Tag Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.baseline.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_resource_policy_exemption" "firewall_subnet_nsg" {
  name                            = "azfw-subnet-no-nsg"
  resource_id                     = var.firewall_subnet_id
  policy_assignment_id            = azurerm_resource_group_policy_assignment.baseline.id
  exemption_category              = "Waiver"
  display_name                    = "AzureFirewallSubnet does not support NSGs"
  description                     = "Azure Firewall subnets cannot be associated with an NSG (platform limitation)."
  policy_definition_reference_ids = ["subnet_nsg"]
}
