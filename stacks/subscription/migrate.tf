# ONE-TIME MIGRATION — delete this file in the PR after the one that applied it.
#
# poc-app1-dev was created by the old single-state vending/ layer (state key vending.tfstate).
# These import blocks adopt its existing resources into the new per-request state
# (subscriptions/app1/poc-app1-dev.tfstate) instead of recreating them. They only
# activate for that request; every other request sees empty maps.
#
# Not imported (created fresh, both harmless): the management-group association
# (a PUT to the group the subscription is already in) and its terraform_data trigger.
# After the apply, vending.tfstate is orphaned: nothing reads it. Delete that blob then.

variable "legacy_import" {
  type        = bool
  default     = true
  description = "Turns the one-time imports off. Only tests set it (mock providers cannot import)."
}

locals {
  migrate = var.legacy_import && local.request.name == "poc-app1-dev"

  legacy_sub   = "/subscriptions/11bb48cc-dd56-4193-9458-9a65e70f8916"
  legacy_rg    = "${local.legacy_sub}/resourceGroups"
  legacy_group = "4c88f750-e497-4d15-99f0-d932830f635a" # grp-az-poc-app1-dev-owners
  legacy_vnet  = "${local.legacy_rg}/rg-poc-app1-dev-network/providers/Microsoft.Network/virtualNetworks/vnet-poc-app1-dev"
  legacy_umi   = "${local.legacy_rg}/rg-poc-app1-dev-app/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-poc-app1-dev-deploy"
}

import {
  for_each = local.migrate ? {
    app     = "${local.legacy_rg}/rg-poc-app1-dev-app"
    network = "${local.legacy_rg}/rg-poc-app1-dev-network"
  } : {}
  to = module.landing_zone.module.vending.module.resourcegroup[each.key].azapi_resource.rg
  id = each.value
}

import {
  for_each = local.migrate ? {
    default = "${local.legacy_rg}/rg-poc-app1-dev-network/providers/Microsoft.Network/networkSecurityGroups/nsg-poc-app1-dev-default"
  } : {}
  to = module.landing_zone.module.vending.module.networksecuritygroup[each.key].azapi_resource.this
  id = each.value
}

import {
  for_each = local.migrate ? {
    spoke = local.legacy_vnet
  } : {}
  to = module.landing_zone.module.vending.module.virtualnetwork[0].module.virtual_networks[each.key].azapi_resource.vnet
  id = each.value
}

import {
  for_each = local.migrate ? {
    app = "${local.legacy_vnet}/subnets/snet-app"
  } : {}
  to = module.landing_zone.module.vending.module.virtualnetwork[0].module.virtual_networks["spoke"].module.subnet[each.key].azapi_resource.subnet[0]
  id = each.value
}

import {
  for_each = local.migrate ? {
    spoke = "${local.legacy_vnet}/virtualNetworkPeerings/peer-88891940-d6e7-5827-a486-d2b164a5778d"
  } : {}
  to = module.landing_zone.module.vending.module.virtualnetwork[0].module.peering_hub_outbound[each.key].azapi_resource.this[0]
  id = each.value
}

import {
  for_each = local.migrate ? {
    spoke = "${local.legacy_rg}/rg-hub-poc/providers/Microsoft.Network/virtualNetworks/vnet-hub-poc/virtualNetworkPeerings/peer-cbe0cbd6-587e-5a9c-9ba6-14b1c0f19464"
  } : {}
  to = module.landing_zone.module.vending.module.virtualnetwork[0].module.peering_hub_inbound[each.key].azapi_resource.this[0]
  id = each.value
}

import {
  for_each = local.migrate ? {
    "owner-${local.legacy_group}-app"          = "${local.legacy_rg}/rg-poc-app1-dev-app/providers/Microsoft.Authorization/roleAssignments/25cfd6d2-0cbc-590f-8789-a35658b197f4"
    "owner-${local.legacy_group}-network-read" = "${local.legacy_rg}/rg-poc-app1-dev-network/providers/Microsoft.Authorization/roleAssignments/f9f17ab4-1475-5a3d-a28c-89d1e3926509"
  } : {}
  to = module.landing_zone.module.vending.module.roleassignment[each.key].azapi_resource.this
  id = each.value
}

import {
  for_each = local.migrate ? {
    deploy = local.legacy_umi
  } : {}
  to = module.landing_zone.module.vending.module.usermanagedidentity[each.key].azapi_resource.umi
  id = each.value
}

import {
  for_each = local.migrate ? {
    main = "${local.legacy_umi}/federatedIdentityCredentials/gh-poc-app1-main"
  } : {}
  to = module.landing_zone.module.vending.module.usermanagedidentity["deploy"].azapi_resource.umi_federated_credential_advanced[each.key]
  id = each.value
}

import {
  for_each = local.migrate ? {
    "deploy/app_rg" = "${local.legacy_rg}/rg-poc-app1-dev-app/providers/Microsoft.Authorization/roleAssignments/924348a1-e028-5ac0-bb8b-e54eb328b080"
  } : {}
  to = module.landing_zone.module.vending.module.roleassignment_umi[each.key].azapi_resource.this
  id = each.value
}

import {
  for_each = local.migrate ? {
    monthly = "${local.legacy_sub}/providers/Microsoft.Consumption/budgets/budget-poc-app1-dev"
  } : {}
  to = module.landing_zone.module.vending.module.budget[each.key].azapi_resource.budget
  id = each.value
}
