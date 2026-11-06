terraform {
  required_version = "~> 1.10"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  # One state per request. The pipeline passes the key with
  #   -backend-config="key=subscriptions/<team>/<name>.tfstate"
  # (the request's path), so the request path is permanent.
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-poc"
    storage_account_name = "sttfstatepoc21602"
    container_name       = "tfstate"
    use_azuread_auth     = true
  }
}

# Credentials come from the environment:
#   local -> az login (Azure CLI)
#   CI    -> ARM_USE_OIDC / ARM_CLIENT_ID / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID
provider "azapi" {}

# Entra ID access groups (modules/landing-zone/access.tf). Same ARM_* credentials.
provider "azuread" {}
