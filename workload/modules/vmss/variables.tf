variable "resource_group_name" {
  description = "Resource group the resources are created in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "name" {
  description = "Scale set name."
  type        = string
  default     = "demo-vmss"
}

variable "subnet_id" {
  description = "Subnet the instances are placed in."
  type        = string
}

variable "lb_backend_address_pool_id" {
  description = "Load balancer backend pool the instances register with."
  type        = string
}

variable "lb_probe_id" {
  description = "Load balancer health probe used for rolling upgrades."
  type        = string
}

variable "custom_data" {
  description = "Base64-encoded cloud-init (e.g. filebase64(\"cloud-init.yaml\"))."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the adminuser account."
  type        = string
}
