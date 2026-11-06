# Minimal ALZ-style hierarchy (proposal §4, Figure 1):
#
# Tenant Root Group
# └── caizin-poc                     intermediate root
#     ├── caizin-poc-platform        platform subscription (state, pipeline identities, hub)
#     ├── caizin-poc-landingzones
#     │   └── caizin-poc-corp        internal, hub-connected workloads
#     ├── caizin-poc-sandbox         experiments
#     └── caizin-poc-decommissioned  retired subscriptions

resource "azurerm_management_group" "root" {
  name         = "caizin-poc"
  display_name = "Caizin PoC"
}

resource "azurerm_management_group" "platform" {
  name                       = "caizin-poc-platform"
  display_name               = "Platform"
  parent_management_group_id = azurerm_management_group.root.id
}

# The platform subscription lives under Platform, not under a landing-zone archetype, so
# landing-zone policies (e.g. Corp's "deny public IP") never hit the hub or the pipeline's
# own resources. Landing zones that share this subscription set manage_management_group: false.
resource "azurerm_management_group_subscription_association" "platform" {
  management_group_id = azurerm_management_group.platform.id
  subscription_id     = "/subscriptions/${var.subscription_id}"
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
