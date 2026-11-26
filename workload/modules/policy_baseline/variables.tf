variable "policy_prefix" {
  description = "Prefix used for the initiative and assignment names."
  type        = string
}

variable "policy_enforce" {
  description = "Whether the assignment is enforced (true) or audit-only (false)."
  type        = bool
}

variable "allowed_locations" {
  description = "Azure regions allowed by the 'Allowed locations' policy."
  type        = list(string)
}

variable "required_tags" {
  description = "Tag names that must be present on resources and inherited from the resource group."
  type        = list(string)
}

variable "resource_group_id" {
  description = "ID of the resource group the baseline is assigned to."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group (used in the assignment description)."
  type        = string
}

variable "location" {
  description = "Region of the policy assignment's managed identity."
  type        = string
}

variable "firewall_subnet_id" {
  description = "ID of AzureFirewallSubnet, which is exempted from the NSG policy."
  type        = string
}
