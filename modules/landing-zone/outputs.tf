output "settings" {
  description = "Resolved settings for this request; known at plan time so reviewers can check them."
  value = {
    name             = local.name
    archetype        = var.request.archetype
    mode             = local.create ? "create" : (local.dedicated ? "adopt" : "adopt-shared")
    management_group = local.create || var.request.manage_management_group ? local.management_group : "(not managed by this request)"
    access_scope     = local.dedicated ? "subscription" : "resource-groups"
    hub_peering      = local.has_network && local.archetype.hub_peering
    owner_role       = local.archetype.owner_role
    budget_monthly   = coalesce(var.request.budget_monthly, local.archetype.budget_default)
    deploy_identity  = local.has_deploy
    resource_groups  = sort([for rg in values(local.resource_groups) : rg.name])
    access = {
      for level, a in local.access_levels : level => {
        group   = "grp-lz-${local.name}-${level}"
        role    = a.role
        members = sort(a.members)
      }
    }
  }
}

output "access_groups" {
  description = "Object IDs of the managed access groups, keyed by access level."
  value       = { for level, g in azuread_group.access : level => g.object_id }
}

output "subscription_id" {
  description = "ID of the vended (or adopted) subscription."
  value       = module.vending.subscription_id
}

output "deploy_identity" {
  description = "Client and tenant IDs for the app team's GitHub workflow (AZURE_CLIENT_ID / AZURE_TENANT_ID), or null."
  value = local.has_deploy ? {
    client_id = module.vending.umi_client_ids["deploy"]
    tenant_id = module.vending.umi_tenant_ids["deploy"]
  } : null
}

output "virtual_network_resource_ids" {
  description = "Spoke VNet resource IDs."
  value       = module.vending.virtual_network_resource_ids
}
