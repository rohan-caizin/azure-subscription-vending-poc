locals {
  has_network = var.request.network != null
  has_deploy  = var.request.github_repo != null

  # Resource groups. Map keys are resource addresses: never rename them.
  resource_groups = merge(
    # New subscriptions: manage NetworkWatcherRG so Azure's auto-created copy can't block cancellation.
    local.create ? { NetworkWatcherRG = { name = "NetworkWatcherRG", tags = local.tags } } : {},
    { app = { name = "rg-${local.name}-app", tags = local.tags } },
    local.has_network ? { network = { name = "rg-${local.name}-network", tags = local.tags } } : {},
  )

  # People: the Entra groups in `owners`. Add or remove a person by changing group membership.
  owner_role_assignments = local.dedicated ? {
    for g in var.request.owners : "owner-${g}" => {
      principal_id             = g
      definition               = local.archetype.owner_role
      resource_group_scope_key = null
    }
    } : merge(
    { for g in var.request.owners : "owner-${g}-app" => {
      principal_id             = g
      definition               = local.archetype.owner_role
      resource_group_scope_key = "app"
    } },
    { for g in(local.has_network ? var.request.owners : []) : "owner-${g}-network-read" => {
      principal_id             = g
      definition               = "Reader"
      resource_group_scope_key = "network"
    } },
  )

  # Deploy identity for the app team's GitHub repo (main branch only).
  # github_repo is used verbatim in the OIDC subject, so it must match how GitHub presents the
  # repo: owner/repo, or owner@ownerId/repo@repoId for immutable-ID subjects (AADSTS700213 = mismatch).
  github_repo_name = local.has_deploy ? replace(split("@", split("/", var.request.github_repo)[1])[0], ".", "-") : null
  deploy_role_assignments = local.dedicated ? {
    subscription = { definition = local.archetype.deploy_role, resource_group_scope_key = null }
    } : {
    app_rg = { definition = local.archetype.deploy_role, resource_group_scope_key = "app" }
  }
}

module "vending" {
  source  = "Azure/avm-ptn-alz-sub-vending/azure"
  version = "0.3.4" # pin exactly; upgrade deliberately, sandbox first

  location         = var.platform.location
  enable_telemetry = false

  # ---------------------------------------------------------------- Subscription
  # Alias name, billing scope and workload are only read when the subscription is created.
  subscription_alias_enabled = local.create
  subscription_alias_name    = local.create ? local.name : null
  subscription_display_name  = local.create ? coalesce(var.request.display_name, local.name) : null
  subscription_billing_scope = local.create ? var.billing_scope : null
  subscription_workload      = local.create ? local.workload : null
  subscription_tags          = local.create ? local.tags : {}
  subscription_id            = local.create ? null : var.request.subscription_id

  subscription_management_group_association_enabled = local.create || var.request.manage_management_group
  subscription_management_group_id                  = local.management_group

  subscription_register_resource_providers_enabled      = local.create
  subscription_register_resource_providers_and_features = local.resource_providers

  # ---------------------------------------------------------------- Resource groups
  resource_group_creation_enabled = true
  resource_groups                 = local.resource_groups

  # ---------------------------------------------------------------- Network
  network_security_group_enabled = local.has_network
  network_security_groups = local.has_network ? {
    default = {
      name               = "nsg-${local.name}-default"
      resource_group_key = "network"
      tags               = local.tags
    }
  } : {}

  virtual_network_enabled = local.has_network
  virtual_networks = local.has_network ? {
    spoke = {
      name               = "vnet-${local.name}"
      resource_group_key = "network"
      address_space      = [var.request.network.address_space]
      tags               = local.tags
      subnets = {
        for key, prefix in var.request.network.subnets : key => {
          name                   = "snet-${key}"
          address_prefix         = prefix
          network_security_group = { key_reference = "default" }
        }
      }

      hub_peering_enabled     = local.archetype.hub_peering
      hub_network_resource_id = local.archetype.hub_peering ? var.platform.hub_vnet_id : null
      # The module defaults use_remote_gateways / allow_gateway_transit to true, which fails
      # with "RemoteVnetHasNoGateways" while the hub has no gateway.
      hub_peering_options_tohub   = { use_remote_gateways = var.platform.hub_has_gateway }
      hub_peering_options_fromhub = { allow_gateway_transit = var.platform.hub_has_gateway }
    }
  } : {}

  # ---------------------------------------------------------------- RBAC (Entra groups only)
  role_assignment_enabled = true
  role_assignments = {
    for k, v in local.owner_role_assignments : k => merge(v, { principal_type = "Group" })
  }

  # ---------------------------------------------------------------- Workload identity
  umi_enabled = local.has_deploy
  user_managed_identities = local.has_deploy ? {
    deploy = {
      name               = "id-${local.name}-deploy"
      resource_group_key = "app"
      tags               = local.tags
      role_assignments = {
        for k, v in local.deploy_role_assignments : k => merge(v, { principal_type = "ServicePrincipal" })
      }
      federated_credentials_advanced = {
        main = {
          name               = "gh-${local.github_repo_name}-main"
          issuer_url         = "https://token.actions.githubusercontent.com"
          subject_identifier = "repo:${var.request.github_repo}:ref:refs/heads/main"
        }
      }
    }
  } : {}

  # ---------------------------------------------------------------- Budget
  # Subscription scope. On a shared subscription it measures the whole subscription's spend.
  budget_enabled = true
  budgets = {
    monthly = {
      name              = "budget-${local.name}"
      amount            = coalesce(var.request.budget_monthly, local.archetype.budget_default)
      time_grain        = "Monthly"
      time_period_start = coalesce(var.request.budget_start, var.platform.budget_start)
      time_period_end   = var.platform.budget_end
      notifications = {
        actual_80 = {
          enabled        = true
          operator       = "GreaterThan"
          threshold      = 80
          threshold_type = "Actual"
          contact_emails = var.request.budget_contacts
        }
        forecast_100 = {
          enabled        = true
          operator       = "GreaterThan"
          threshold      = 100
          threshold_type = "Forecasted"
          contact_emails = var.request.budget_contacts
        }
      }
    }
  }
}
