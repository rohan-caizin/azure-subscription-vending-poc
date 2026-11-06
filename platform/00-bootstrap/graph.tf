# Microsoft Graph application permissions for the pipeline identities, so landing-zone
# access (people -> managed Entra groups) is driven from the request files.
#
# Least privilege:
#   apply: Group.Create         create groups; it then owns and manages ONLY the groups it created
#          User.Read.All        resolve user principal names to object IDs
#          GroupMember.Read.All read groups and their members
#   plan : User.Read.All, GroupMember.Read.All  (plans and nightly drift, read-only)
#
# Granting Graph application permissions needs a Global Administrator or Privileged Role
# Administrator, so this stays in the bootstrap layer applied by a person with `az login`.

locals {
  graph_permissions = {
    apply = ["Group.Create", "User.Read.All", "GroupMember.Read.All"]
    plan  = ["User.Read.All", "GroupMember.Read.All"]
  }

  graph_assignments = merge([
    for identity, roles in local.graph_permissions : {
      for role in roles : "${identity}-${role}" => { identity = identity, role = role }
    }
  ]...)
}

# Microsoft Graph's service principal in this tenant (well-known application ID).
data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000"
}

resource "azuread_app_role_assignment" "graph" {
  for_each = local.graph_assignments

  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids[each.value.role]
  principal_object_id = azurerm_user_assigned_identity.pipeline[each.value.identity].principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}
