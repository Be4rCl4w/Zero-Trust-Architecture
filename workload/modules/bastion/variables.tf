variable "resource_group_name" {
  description = "Resource group the Bastion host is created in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "name" {
  description = "Bastion host name."
  type        = string
  default     = "demo_bastion"
}

variable "sku" {
  description = "Bastion SKU. Tunneling (native client) requires Standard or higher."
  type        = string
  default     = "Standard"
}

variable "tunneling_enabled" {
  description = "Enable native client support (az network bastion tunnel/ssh)."
  type        = bool
  default     = true
}

variable "subnet_id" {
  description = "ID of AzureBastionSubnet (must be /26 or larger)."
  type        = string
}

variable "public_ip_id" {
  description = "ID of a Standard-SKU static public IP."
  type        = string
}
