# People: the request lists users by user principal name (UPN). For each access level the
# pipeline owns one Entra security group, sets EXACTLY the listed members (anyone added by
# hand is removed on the next apply and shows up as drift), and grants the group its role.
#
#   access.owners  -> grp-lz-<name>-owners  -> archetype owner_role (Contributor)
#   access.readers -> grp-lz-<name>-readers -> Reader               (only if listed)
#
# Graph permissions (granted once in platform/00-bootstrap/graph.tf):
#   apply: Group.Create (manages only groups it created), User.Read.All, GroupMember.Read.All
#   plan : User.Read.All, GroupMember.Read.All

locals {
  access_levels = merge(
    { owners = { members = var.request.access.owners, role = local.archetype.owner_role } },
    length(var.request.access.readers) > 0 ? { readers = { members = var.request.access.readers, role = "Reader" } } : {},
  )
}

# Resolve every UPN to an object ID. Fails the plan if someone does not exist in the tenant.
data "azuread_users" "access" {
  for_each = local.access_levels

  user_principal_names = each.value.members
}

resource "azuread_group" "access" {
  for_each = local.access_levels

  display_name            = "grp-lz-${local.name}-${each.key}"
  description             = "${each.key} of landing zone ${local.name}. Managed by subscription vending (subscriptions/**/${local.name}.yaml); manual changes are reverted."
  security_enabled        = true
  prevent_duplicate_names = true

  # The pipeline's apply identity must stay owner: with Group.Create it may only manage groups it owns.
  owners  = [var.platform.pipeline_apply_principal_id]
  members = data.azuread_users.access[each.key].object_ids
}
