variable "policy_prefix" {
  type    = string
  default = "demo"
}

variable "policy_enforce" {
  description = "false = DoNotEnforce (report only). true = Deny/DeployIfNotExists/Modify are active."
  type        = bool
  default     = false
}

variable "allowed_locations" {
  type    = list(string)
  default = ["northeurope", "swedencentral"]
}

variable "required_tags" {
  type    = list(string)
  default = ["owner", "environment"]
}
