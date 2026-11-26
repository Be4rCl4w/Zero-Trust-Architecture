variable "resource_group_name" {
  description = "Resource group the resources are created in."
  type        = string
}

variable "location" {
  description = "Azure region for the SQL server (may differ from the resource group's region)."
  type        = string
  default     = "swedencentral"
}

variable "server_name" {
  description = "SQL server name (globally unique)."
  type        = string
}

variable "database_name" {
  description = "SQL database name."
  type        = string
}

variable "entra_admin_object_id" {
  description = "Object ID of the Entra ID user or group that administers the server."
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant ID."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace that receives diagnostics."
  type        = string
}
