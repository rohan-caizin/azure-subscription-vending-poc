# Hub network (proposal §4, Figure 2), without Firewall / VPN / Bastion to stay at ~$0.
# Spokes created by the vending module peer to this VNet.

resource "azurerm_resource_group" "hub" {
  name     = "rg-hub-poc"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-poc"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = var.hub_address_space
  tags                = var.tags
}
