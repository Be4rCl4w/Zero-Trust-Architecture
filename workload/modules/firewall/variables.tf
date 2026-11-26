variable "resource_group_name" {
  description = "Resource group the resources are created in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "name" {
  description = "Azure Firewall name."
  type        = string
  default     = "demo_firewall"
}

variable "policy_name" {
  description = "Firewall policy name."
  type        = string
  default     = "demo-fw-policy"
}

variable "rule_collection_group_name" {
  description = "Rule collection group name."
  type        = string
  default     = "demo-rcg"
}

variable "firewall_subnet_id" {
  description = "ID of AzureFirewallSubnet."
  type        = string
}

variable "public_ip_id" {
  description = "ID of the public IP used by the firewall."
  type        = string
}

variable "route_table_name" {
  description = "Name of the route table that forces egress through the firewall."
  type        = string
  default     = "demo-route-table"
}

variable "spoke_subnet_ids" {
  description = "Subnets to attach the route table to: name => subnet ID."
  type        = map(string)
}

variable "aca_subnet_id" {
  description = "ID of the Container Apps / GitHub runner subnet to attach the route table to."
  type        = string
}

variable "aca_rule_source_addresses" {
  description = "Source CIDRs for the Container Apps network rule."
  type        = list(string)
  default     = ["10.0.3.0/26"]
}

variable "aca_rule_destination_service_tags" {
  description = "Destination service tags for the Container Apps network rule (TCP/443)."
  type        = list(string)
  default = [
    "MicrosoftContainerRegistry", "AzureFrontDoor.FirstParty",
    "AzureActiveDirectory", "AzureContainerRegistry", "AzureKeyVault",
    "AzureMonitor"
  ]
}

variable "app_rule_source_addresses" {
  description = "Source CIDRs for the HTTPS application rule."
  type        = list(string)
  default     = ["10.20.0.0/16", "10.0.3.0/26"]
}

variable "app_rule_destination_fqdns" {
  description = "FQDNs allowed over HTTPS/443."
  type        = list(string)
  default = [
    "github.com", "*.github.com", "*.actions.githubusercontent.com",
    "*.githubusercontent.com", "*.blob.core.windows.net", "*.aadcdn.msftauth.net",
    "*.azurecr.io", "*.vault.azure.net", "login.microsoftonline.com", "*.aadcdn.msauth.net",
    "*.azure.com", "*.microsoft.com", "mcr.microsoft.com", "*.data.mcr.microsoft.com",
    "releases.hashicorp.com", "registry.terraform.io", "*.ubuntu.com", "*.nodesource.com",
    "registry.npmjs.org", "nodejs.org"
  ]
}

variable "apt_rule_source_addresses" {
  description = "Source CIDRs for the Ubuntu apt HTTP rule."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "apt_rule_destination_fqdns" {
  description = "FQDNs allowed over HTTP/80 for apt."
  type        = list(string)
  default     = ["azure.archive.ubuntu.com", "archive.ubuntu.com", "security.ubuntu.com"]
}
