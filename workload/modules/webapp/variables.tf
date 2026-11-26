variable "resource_group_name" {
  description = "Resource group the resources are created in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "name" {
  description = "Web app name (globally unique)."
  type        = string
}

variable "service_plan_name" {
  description = "App Service plan name."
  type        = string
  default     = "My-demo-plan"
}

variable "service_plan_sku" {
  description = "App Service plan SKU."
  type        = string
  default     = "P0v3"
}

variable "app_insights_name" {
  description = "Application Insights name."
  type        = string
  default     = "demo-appi"
}

variable "node_version" {
  description = "Node.js runtime version."
  type        = string
  default     = "24-lts"
}

variable "subnet_id" {
  description = "Delegated subnet used for regional VNet integration."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace backing Application Insights."
  type        = string
}

variable "app_lb_private_ip" {
  description = "Private IP of the internal load balancer; exposed to the app as BACKEND_API_URL."
  type        = string
}
