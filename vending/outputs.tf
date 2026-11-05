output "landing_zones" {
  description = "Per landing zone: subscription, management group, network and workload identity."
  value = {
    for k, lz in module.landing_zone : k => {
      subscription_id     = lz.subscription_id
      management_group    = local.archetype_management_group[local.landing_zones[k].archetype]
      resource_group_ids  = lz.resource_group_resource_ids
      virtual_network_ids = lz.virtual_network_resource_ids
      subnet_ids          = lz.virtual_network_subnet_resource_ids
      umi_client_ids      = lz.umi_client_ids
    }
  }
}
