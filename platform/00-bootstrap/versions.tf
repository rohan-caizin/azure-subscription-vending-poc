terraform {
  required_version = "~> 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  # State key kept from when this layer lived in identity/: moving the folder changed nothing in Azure.
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-poc"
    storage_account_name = "sttfstatepoc21602"
    container_name       = "tfstate"
    key                  = "identity.tfstate"
    use_azuread_auth     = true
  }
}
