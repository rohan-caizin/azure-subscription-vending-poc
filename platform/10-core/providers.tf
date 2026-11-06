provider "azurerm" {
  features {}

  subscription_id = var.subscription_id

  # Required providers were registered during bootstrap; don't let azurerm register dozens more.
  resource_provider_registrations = "none"
}
