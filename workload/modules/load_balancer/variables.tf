variable "resource_group_name" {
  description = "Resource group the resources are created in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "name" {
  description = "Internal load balancer name."
  type        = string
  default     = "my-lb"
}

variable "subnet_id" {
  description = "Subnet that hosts the load balancer's private frontend."
  type        = string
}

variable "app_lb_private_ip" {
  description = "Static private frontend IP."
  type        = string
}
