# Lets the apply identity create subscriptions on the billing scope (Subscription Alias API).
#
# Billing roles are separate from Azure RBAC: only a billing account / invoice section
# owner can grant them, so this stays in the bootstrap layer that a person applies with
# `az login`. The pipeline cannot grant itself this role.
#
# "Azure subscription creator" on an MCA invoice section. For EA, the equivalent is the
# "SubscriptionCreator" role on the enrollment account (different API, not covered here).
#
# Caveat: this is a one-shot POST. Terraform does not read it back, so removing it here
# does NOT revoke the role (do that in Cost Management + Billing > Invoice section > Access control).

locals {
  subscription_creator_role = "30000000-aaaa-bbbb-cccc-100000000006" # Azure subscription creator
}

resource "azapi_resource_action" "apply_subscription_creator" {
  count = var.billing_scope == null ? 0 : 1

  type        = "Microsoft.Billing/billingAccounts/billingProfiles/invoiceSections@2024-04-01"
  resource_id = var.billing_scope
  action      = "createBillingRoleAssignment"
  method      = "POST"
  body = {
    principalId       = azurerm_user_assigned_identity.pipeline["apply"].principal_id
    principalTenantId = azurerm_user_assigned_identity.pipeline["apply"].tenant_id
    roleDefinitionId  = "${var.billing_scope}/billingRoleDefinitions/${local.subscription_creator_role}"
  }
}
