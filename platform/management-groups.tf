# Minimal ALZ-style hierarchy (proposal §4, Figure 1):
#
# Tenant Root Group
# └── caizin-poc                     intermediate root
#     ├── caizin-poc-landingzones
#     │   └── caizin-poc-corp        internal, hub-connected workloads
#     ├── caizin-poc-sandbox         experiments
#     └── caizin-poc-decommissioned  retired subscriptions

resource "azurerm_management_group" "root" {
  name         = "caizin-poc"
  display_name = "Caizin PoC"
}

resource "azurerm_management_group" "landingzones" {
  name                       = "caizin-poc-landingzones"
  display_name               = "Landing Zones"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "corp" {
  name                       = "caizin-poc-corp"
  display_name               = "Corp"
  parent_management_group_id = azurerm_management_group.landingzones.id
}

resource "azurerm_management_group" "sandbox" {
  name                       = "caizin-poc-sandbox"
  display_name               = "Sandbox"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "decommissioned" {
  name                       = "caizin-poc-decommissioned"
  display_name               = "Decommissioned"
  parent_management_group_id = azurerm_management_group.root.id
}
