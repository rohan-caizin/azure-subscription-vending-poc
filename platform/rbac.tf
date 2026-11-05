# Pipeline permissions on the PoC hierarchy (inherited by every subscription moved under it).
# The identities themselves, their OIDC credentials and their subscription / state-container
# roles live in identity/ (apply that layer first).
#
# PoC simplification: apply = Owner. Proposal §7 target is Contributor + MG Contributor
# + conditioned RBAC Administrator + peering-only role.

data "terraform_remote_state" "identity" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate-poc"
    storage_account_name = "sttfstatepoc21602"
    container_name       = "tfstate"
    key                  = "identity.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  pipeline_principals = {
    apply = data.terraform_remote_state.identity.outputs.apply_principal_id
    plan  = data.terraform_remote_state.identity.outputs.plan_principal_id
  }
}

resource "azurerm_role_assignment" "apply_owner" {
  scope                = azurerm_management_group.root.id
  role_definition_name = "Owner"
  principal_id         = local.pipeline_principals.apply
  principal_type       = "ServicePrincipal"
  description          = "Vending PoC pipeline (apply)"
}

resource "azurerm_role_assignment" "plan_reader" {
  scope                = azurerm_management_group.root.id
  role_definition_name = "Reader"
  principal_id         = local.pipeline_principals.plan
  principal_type       = "ServicePrincipal"
  description          = "Vending PoC pipeline (plan / drift)"
}
