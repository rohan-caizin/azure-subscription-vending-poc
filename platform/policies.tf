# A small, hand-picked subset of guardrails (proposal §6) using built-in policy definitions.
# Production would use the full ALZ library instead.

locals {
  builtin = "/providers/Microsoft.Authorization/policyDefinitions"
}

# --- Intermediate root: applies to everything under caizin-poc -------------------------

# Resources may only be created in allowed regions (does not cover resource groups).
resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed locations"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = "${local.builtin}/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}

# Resource groups may only be created in allowed regions.
resource "azurerm_management_group_policy_assignment" "allowed_locations_rg" {
  name                 = "allowed-locations-rg"
  display_name         = "Allowed locations for resource groups"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = "${local.builtin}/e765b5de-1225-4ba3-bd56-1ac6695af988"
  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}

# Resource groups must carry a CostCentre tag. Audit-first (proposal §6): DoNotEnforce.
resource "azurerm_management_group_policy_assignment" "require_rg_costcentre" {
  name                 = "require-rg-costcentre"
  display_name         = "Require CostCentre tag on resource groups (audit)"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = "${local.builtin}/96670d01-0a4d-4649-9c89-2d3abc0a5025"
  enforce              = false
  parameters = jsonencode({
    tagName = { value = "CostCentre" }
  })
}

# --- Corp: no public IPs ------------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "corp_deny_public_ip" {
  name                 = "corp-deny-pip"
  display_name         = "Corp: deny public IP addresses"
  management_group_id  = azurerm_management_group.corp.id
  policy_definition_id = "${local.builtin}/6c112d4e-5bc7-47ae-a041-ea2d9dccd749" # Not allowed resource types
  parameters = jsonencode({
    listOfResourceTypesNotAllowed = { value = ["Microsoft.Network/publicIPAddresses"] }
  })
}

# --- Decommissioned: deny every new resource ------------------------------------------------

resource "azurerm_management_group_policy_assignment" "decommissioned_deny_all" {
  name                 = "decom-deny-all"
  display_name         = "Decommissioned: deny all new resources"
  management_group_id  = azurerm_management_group.decommissioned.id
  policy_definition_id = "${local.builtin}/a08ec900-254a-4555-9bf5-e42af04b5c5c" # Allowed resource types
  parameters = jsonencode({
    listOfResourceTypesAllowed = { value = [] }
  })
}
