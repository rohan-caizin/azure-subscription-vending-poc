# Subscription vending (proposal §5): one YAML file = one landing zone.
#
#   landing-zones/<archetype>/<request-key>.yaml
#
#   <archetype>    folder name -> target management group (corp | sandbox | decommissioned)
#   <request-key>  file name   -> map key for every resource. NEVER RENAME a request file:
#                                 a new key means destroy + recreate (blocked by the CI destroy guard).

locals {
  lz_root = "${path.module}/landing-zones"

  # Map of request-key => request object (+ archetype from the folder).
  # Duplicate keys across folders make this expression fail, which is intended.
  landing_zones = {
    for f in fileset(local.lz_root, "*/*.yaml") :
    trimsuffix(basename(f), ".yaml") => merge(
      yamldecode(file("${local.lz_root}/${f}")),
      { archetype = dirname(f) }
    )
  }

  archetype_management_group = {
    corp           = "caizin-poc-corp"
    sandbox        = "caizin-poc-sandbox"
    decommissioned = "caizin-poc-decommissioned"
  }
}

module "landing_zone" {
  source   = "Azure/avm-ptn-alz-sub-vending/azure"
  version  = "0.3.4"
  for_each = local.landing_zones

  location         = each.value.location
  enable_telemetry = false

  # ---------------------------------------------------------------- Subscription
  # PoC: adopt an existing subscription instead of creating one through the Subscription
  # Alias API. With EA/MCA billing this becomes:
  #   subscription_alias_enabled = true, subscription_billing_scope = ..., subscription_workload = ...
  subscription_alias_enabled                        = false
  subscription_id                                   = try(each.value.subscription_id, var.subscription_id)
  subscription_management_group_association_enabled = try(each.value.mg_association, true)
  subscription_management_group_id                  = local.archetype_management_group[each.value.archetype]
  subscription_register_resource_providers_enabled  = false # registered during bootstrap

  # ---------------------------------------------------------------- Resource groups
  # No "NetworkWatcherRG" here: Azure already created it with the hub VNet.
  resource_group_creation_enabled = true
  resource_groups = {
    network = {
      name = "rg-${each.key}-network"
      tags = each.value.tags
    }
    app = {
      name = "rg-${each.key}-app"
      tags = each.value.tags
    }
  }

  # ---------------------------------------------------------------- NSG
  network_security_group_enabled = true
  network_security_groups = {
    default = {
      name               = "nsg-${each.key}-default"
      resource_group_key = "network"
      tags               = each.value.tags
    }
  }

  # ---------------------------------------------------------------- Spoke VNet + hub peering
  virtual_network_enabled = true
  virtual_networks = {
    spoke = {
      name                    = "vnet-${each.key}"
      resource_group_key      = "network"
      address_space           = each.value.network.address_space
      tags                    = each.value.tags
      hub_network_resource_id = var.hub_vnet_id
      hub_peering_enabled     = true
      # PoC hub has no VPN/ExpressRoute gateway. Module defaults (spoke useRemoteGateways=true,
      # hub allowGatewayTransit=true) fail with "RemoteVnetHasNoGateways". Flip back once a gateway exists.
      hub_peering_options_tohub   = { use_remote_gateways = false }
      hub_peering_options_fromhub = { allow_gateway_transit = false }
      subnets = {
        app = {
          name                   = "snet-app"
          address_prefix         = cidrsubnet(each.value.network.address_space[0], 1, 0)
          network_security_group = { key_reference = "default" }
        }
      }
    }
  }

  # ---------------------------------------------------------------- RBAC (Entra groups only)
  # Single-subscription mode: scope the app team to its own resource groups, not the
  # subscription, so it cannot touch the platform resource groups.
  role_assignment_enabled = true
  role_assignments = {
    owners_app = {
      principal_id             = each.value.access.owners_group_object_id
      definition               = "Contributor" # stand-in for ALZ "Application-Owners"
      resource_group_scope_key = "app"
      principal_type           = "Group"
    }
    owners_network_read = {
      principal_id             = each.value.access.owners_group_object_id
      definition               = "Reader"
      resource_group_scope_key = "network"
      principal_type           = "Group"
    }
  }

  # ---------------------------------------------------------------- Budget
  budget_enabled = true
  budgets = {
    monthly = {
      name              = "budget-${each.key}"
      amount            = each.value.budget.monthly_amount
      time_grain        = "Monthly"
      time_period_start = "2026-11-01T00:00:00Z"
      time_period_end   = "2027-10-31T00:00:00Z"
      notifications = {
        actual_80 = {
          enabled        = true
          operator       = "GreaterThan"
          threshold      = 80
          threshold_type = "Actual"
          contact_emails = each.value.budget.alert_emails
        }
        forecast_100 = {
          enabled        = true
          operator       = "GreaterThan"
          threshold      = 100
          threshold_type = "Forecasted"
          contact_emails = each.value.budget.alert_emails
        }
      }
    }
  }

  # ---------------------------------------------------------------- Workload identity
  # Lets the app team's own repo deploy into rg-<key>-app with GitHub OIDC (no secrets).
  umi_enabled = true
  user_managed_identities = {
    deploy = {
      name               = "id-${each.key}-deploy"
      resource_group_key = "app"
      tags               = each.value.tags
      role_assignments = {
        app_rg = {
          definition               = "Contributor"
          resource_group_scope_key = "app"
          principal_type           = "ServicePrincipal"
        }
      }
      federated_credentials_github = {
        main = {
          name         = "gh-${each.value.github.repository}-main"
          organization = each.value.github.organization
          repository   = each.value.github.repository
          entity       = "branch"
          value        = "main"
        }
      }
    }
  }
}
