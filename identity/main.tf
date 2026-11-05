# Pipeline identities for GitHub Actions (proposal §5 "OIDC identity, no stored secrets").
#
# User-assigned managed identities + federated credentials:
#   - no client secrets can exist (managed identities have none)
#   - only azurerm / Azure RBAC is needed (no Entra ID admin rights)
#
# Bootstrap layer: applied LOCALLY once with `az login`. The pipeline cannot create the
# identity it signs in with.

locals {
  github_issuer   = "https://token.actions.githubusercontent.com"
  github_audience = ["api://AzureADTokenExchange"]

  subscription_scope = "/subscriptions/${var.subscription_id}"
  state_container_scope = join("/", [
    local.subscription_scope,
    "resourceGroups", var.state.resource_group_name,
    "providers/Microsoft.Storage/storageAccounts", var.state.storage_account_name,
    "blobServices/default/containers", var.state.container_name,
  ])

  # One entry per identity: GitHub OIDC subjects it trusts + the Azure roles it gets.
  # Management-group roles (caizin-poc) are assigned in platform/rbac.tf.
  identities = {
    plan = {
      name = "id-vending-poc-plan"
      subjects = {
        gh-pr   = "repo:${var.github_repo}:pull_request"        # vending-pr: validate + plan
        gh-main = "repo:${var.github_repo}:ref:refs/heads/main" # vending-apply plan job, vending-drift
      }
      roles = {
        reader = { role = "Reader", scope = local.subscription_scope }
        state  = { role = "Storage Blob Data Contributor", scope = local.state_container_scope } # state lock needs write
      }
    }
    apply = {
      name = "id-vending-poc-apply"
      subjects = {
        gh-env-apply = "repo:${var.github_repo}:environment:${var.apply_environment}" # only after approval
      }
      roles = {
        # PoC simplification. Proposal §7 target: Contributor + MG Contributor
        # + conditioned RBAC Administrator + peering-only role.
        owner = { role = "Owner", scope = local.subscription_scope }
        state = { role = "Storage Blob Data Contributor", scope = local.state_container_scope }
      }
    }
  }

  federated_credentials = merge([
    for id_key, id in local.identities : {
      for cred_name, subject in id.subjects : "${id_key}-${cred_name}" => {
        identity = id_key
        name     = cred_name
        subject  = subject
      }
    }
  ]...)

  role_assignments = merge([
    for id_key, id in local.identities : {
      for ra_key, ra in id.roles : "${id_key}-${ra_key}" => merge(ra, { identity = id_key })
    }
  ]...)
}

resource "azurerm_resource_group" "identity" {
  name     = "rg-identity-poc"
  location = var.location
  tags     = var.tags
}

resource "azurerm_user_assigned_identity" "pipeline" {
  for_each = local.identities

  name                = each.value.name
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "github" {
  for_each = local.federated_credentials

  name                = each.value.name
  resource_group_name = azurerm_resource_group.identity.name
  parent_id           = azurerm_user_assigned_identity.pipeline[each.value.identity].id
  issuer              = local.github_issuer
  audience            = local.github_audience
  subject             = each.value.subject
}

resource "azurerm_role_assignment" "pipeline" {
  for_each = local.role_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.pipeline[each.value.identity].principal_id
  principal_type       = "ServicePrincipal"
  description          = "Vending PoC pipeline (${each.value.identity})"
}
