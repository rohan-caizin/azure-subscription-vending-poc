output "settings" {
  description = "Resolved settings for this request; known at plan time so reviewers can check them."
  value = {
    name             = local.name
    archetype        = var.request.archetype
    mode             = local.create ? "create" : (local.dedicated ? "adopt" : "adopt-shared")
    management_group = local.management_group
    access_scope     = local.dedicated ? "subscription" : "resource-groups"
    hub_peering      = local.has_network && local.archetype.hub_peering
    owner_role       = local.archetype.owner_role
    budget_monthly   = coalesce(var.request.budget_monthly, local.archetype.budget_default)
    deploy_identity  = local.has_deploy
    resource_groups  = sort([for rg in values(local.resource_groups) : rg.name])
  }
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
