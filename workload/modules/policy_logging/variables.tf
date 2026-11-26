variable "policy_prefix" {
  description = "Prefix used for the assignment name."
  type        = string
}

variable "policy_enforce" {
  description = "Whether the assignment is enforced (true) or audit-only (false)."
  type        = bool
}

variable "resource_group_id" {
  description = "ID of the resource group the logging initiative is assigned to."
  type        = string
}

variable "location" {
  description = "Region of the policy assignment's managed identity."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace that receives resource logs."
  type        = string
}
