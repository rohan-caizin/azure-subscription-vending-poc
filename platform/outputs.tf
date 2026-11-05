output "hub_vnet_id" {
  description = "Resource ID of the hub VNet. Set as GitHub variable HUB_VNET_ID and vending var hub_vnet_id."
  value       = azurerm_virtual_network.hub.id
}

output "management_group_ids" {
  description = "Management group names keyed by archetype (used by the vending layer)."
  value = {
    root           = azurerm_management_group.root.name
    landingzones   = azurerm_management_group.landingzones.name
    corp           = azurerm_management_group.corp.name
    sandbox        = azurerm_management_group.sandbox.name
    decommissioned = azurerm_management_group.decommissioned.name
  }
}
