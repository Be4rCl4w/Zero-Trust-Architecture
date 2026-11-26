variable "resource_group_name" {
  description = "Resource group the resources are created in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "name" {
  description = "Application Gateway name."
  type        = string
  default     = "example-appgw"
}

variable "identity_name" {
  description = "Name of the user-assigned identity the gateway uses to read Key Vault."
  type        = string
  default     = "appgw-managed-identity"
}

variable "waf_policy_name" {
  description = "WAF policy name."
  type        = string
  default     = "example-waf-policy"
}

variable "certificate_name" {
  description = "Name of the self-signed TLS certificate created in Key Vault."
  type        = string
  default     = "appgw-tls-cert"
}

variable "diagnostic_setting_name" {
  description = "Name of the diagnostic setting that sends gateway logs to Log Analytics."
  type        = string
  default     = "appgw-to-law"
}

variable "subnet_id" {
  description = "Dedicated Application Gateway subnet."
  type        = string
}

variable "public_ip_id" {
  description = "Public IP ID for the frontend."
  type        = string
}

variable "public_ip_fqdn" {
  description = "FQDN of the public IP (used as the certificate subject / SAN)."
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault that stores the TLS certificate."
  type        = string
}

variable "backend_fqdn" {
  description = "FQDN of the backend (web app default hostname)."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace that receives gateway logs."
  type        = string
}
