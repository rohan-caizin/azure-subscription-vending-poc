terraform {
  required_version = "~> 1.10"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }

  # Same storage account as the platform layer, separate state key.
  # Auth: Azure CLI locally; OIDC in GitHub Actions (ARM_USE_OIDC=true is set by the workflows).
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-poc"
    storage_account_name = "sttfstatepoc21602"
    container_name       = "tfstate"
    key                  = "vending.tfstate"
    use_azuread_auth     = true
  }
}
