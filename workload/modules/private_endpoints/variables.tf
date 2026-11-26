variable "resource_group_name" {
  description = "Resource group the resources are created in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "vnets" {
  description = "VNet IDs that private DNS zones can be linked to: key => VNet ID."
  type        = map(string)
}

variable "dns_zones" {
  description = "Private DNS zones: key => { name, vnets = keys of var.vnets to link }."
  type = map(object({
    name  = string
    vnets = list(string)
  }))
  default = {
    sql    = { name = "privatelink.database.windows.net", vnets = ["spoke"] }
    kv     = { name = "privatelink.vaultcore.azure.net", vnets = ["spoke", "hub"] }
    webapp = { name = "privatelink.azurewebsites.net", vnets = ["hub"] }
    acr    = { name = "privatelink.azurecr.io", vnets = ["spoke", "hub"] }
  }
}

variable "endpoints" {
  description = "Private endpoints to create: key => target. dns_key must be a key of dns_zones; each endpoint has its own subnet."
  type = map(object({
    dns_key     = string
    resource_id = string
    subresource = string
    subnet_id   = string
  }))
}
