provider "azurerm" {
  features {}

  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}

# Billing role assignment (billing.tf) only; azurerm has no MCA billing-role resource.
provider "azapi" {
  subscription_id = var.subscription_id
}

# Microsoft Graph permissions for the pipeline identities (graph.tf). Uses `az login`.
provider "azuread" {}
