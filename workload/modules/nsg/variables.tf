variable "resource_group_name" {
  description = "Resource group the resources are created in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "hub_subnets" {
  description = "Hub subnets (network module output). Must contain AppGatewaySubnet and AzureBastionSubnet."
  type = map(object({
    id               = string
    address_prefixes = list(string)
  }))
}

variable "spoke_subnets" {
  description = "Spoke subnets (network module output). Must contain WebSubnet, AppSubnet, DataSubnet, InfraPrivateEndpointsSubnet and WebEndpointSubnet."
  type = map(object({
    id               = string
    address_prefixes = list(string)
  }))
}

variable "aca_subnet_address_prefixes" {
  description = "Address prefixes of the Container Apps / GitHub runner subnet."
  type        = list(string)
}

variable "app_lb_private_ip" {
  description = "Static private frontend IP of the internal load balancer."
  type        = string
}
