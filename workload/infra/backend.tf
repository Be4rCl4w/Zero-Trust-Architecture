terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate1unique123"
    container_name        = "tfstate"
    key                   = "workload.tfstate"
    use_azuread_auth      = true
    use_oidc              = true
  }
}
