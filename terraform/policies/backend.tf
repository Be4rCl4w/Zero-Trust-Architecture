terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstatedemo123"
    container_name       = "tfstate"
    key                  = "policy.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}