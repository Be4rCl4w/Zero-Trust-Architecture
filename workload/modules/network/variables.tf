variable "resource_group_name" {
  description = "Resource group the resources are created in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the existing hub virtual network."
  type        = string
}

variable "spoke_vnet_name" {
  description = "Name of the existing spoke virtual network."
  type        = string
}

variable "hub_subnets" {
  description = "Hub subnets to create: name => address prefix."
  type        = map(string)
  default = {
    "AzureBastionSubnet" = "10.0.1.0/26" # Azure requires /26 or larger for Bastion
    "AppGatewaySubnet"   = "10.0.2.0/26"
  }
}

variable "spoke_subnets" {
  description = <<-DESC
    Spoke subnets to create.
    delegate    = add the Microsoft.Web/serverFarms delegation (App Service VNet integration).
    pe_policies = private_endpoint_network_policies ("Enabled" makes NSG rules apply to private endpoints).
  DESC
  type = map(object({
    address_prefix = string
    delegate       = bool
    pe_policies    = string
  }))
  default = {
    "WebSubnet"  = { address_prefix = "10.20.0.0/24", delegate = true, pe_policies = "Disabled" }
    "AppSubnet"  = { address_prefix = "10.20.1.0/24", delegate = false, pe_policies = "Disabled" }
    "DataSubnet" = { address_prefix = "10.20.3.0/24", delegate = false, pe_policies = "Enabled" }
    # ACR private endpoint, so the app gateway can't reach ACR
    "InfraPrivateEndpointsSubnet" = { address_prefix = "10.20.4.0/24", delegate = false, pe_policies = "Enabled" }
    # Web app and Key Vault private endpoints
    "WebEndpointSubnet" = { address_prefix = "10.20.5.0/24", delegate = false, pe_policies = "Enabled" }
  }
}

variable "public_ip_names" {
  description = "Public IPs to create. Only \"AppGateway\" receives the DNS label."
  type        = list(string)
  default     = ["AppGateway", "AzureFirewall", "AzureBastion"]
}

variable "app_gw_dns_prefix" {
  description = "domain_name_label applied to the \"AppGateway\" public IP."
  type        = string
}
