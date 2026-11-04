
variable "prefix"          { 
  type = string  
  default = "ghrunner" 
}

variable "github_app_key" {
  type    = string
  sensitive = true
}
variable "github_owner" { 
  type = string 
}                        

variable "github_runner_scope" { 
  type = string   
  default = "repo"
} 
variable "gh_url" {
  type = string
}

variable "reg_token_url" {
  type = string
  default = "https://api.github.com/repos/Be4rCl4w/Zero-Trust-Architecture/actions/runners/registration-token"
}

variable "github_repo" { 
  type = string
  default = "Zero-Trust-Architecture"  
}        

variable "github_app_id" { 
  type = number
}
variable "github_app_installation_id" {
  type = number
}

variable "runner_labels" { 
  type = string
  default = "self-hosted, aca" 
}
variable "max_runners"   { 
  type = number  
  default = 10 
}
#variable "runner_image_tag" {
  #type = string
#}