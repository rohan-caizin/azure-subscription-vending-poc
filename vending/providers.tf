# The vending module uses azapi only. Credentials come from the environment:
#   local  -> az login (Azure CLI)
#   CI     -> ARM_USE_OIDC / ARM_CLIENT_ID / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID
provider "azapi" {}
