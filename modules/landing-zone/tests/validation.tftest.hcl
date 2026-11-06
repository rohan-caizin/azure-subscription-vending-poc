# Request validation and archetype mapping, against mocked providers.
# Run from modules/landing-zone:  terraform init -backend=false && terraform test

# Only azapi talks to Azure. random and time run locally; modtm is unused with telemetry off.
mock_provider "azapi" {
  # The vending module reads subscription and management group lists.
  mock_data "azapi_resource_list" {
    defaults = {
      output = { value = [] }
    }
  }

  # Fixed IDs so values derived from created resources resolve during plan.
  mock_resource "azapi_resource" {
    defaults = {
      output = {
        properties = {
          subscriptionId = "00000000-0000-0000-0000-00000000aaaa"
          principalId    = "00000000-0000-0000-0000-00000000bbbb"
          clientId       = "00000000-0000-0000-0000-00000000cccc"
          tenantId       = "00000000-0000-0000-0000-00000000dddd"
        }
      }
    }
  }
}

variables {
  platform = {
    location                 = "centralindia"
    platform_subscription_id = "11111111-1111-1111-1111-111111111111"
    management_groups        = { corp = "mg-corp", sandbox = "mg-sandbox" }
    hub_vnet_id              = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
    hub_has_gateway          = false
    budget_start             = "2026-11-01T00:00:00Z"
    budget_end               = "2027-10-31T00:00:00Z"
    default_tags             = { ManagedBy = "subscription-vending" }
  }
  billing_scope = "/providers/Microsoft.Billing/billingAccounts/a/billingProfiles/b/invoiceSections/c"

  request = {
    name            = "team-app-dev"
    archetype       = "corp"
    owners          = ["33333333-3333-3333-3333-333333333333"]
    budget_contacts = ["team@example.com"]
    tags            = { Environment = "Dev", Project = "team-app", CostCentre = "CC-POC", Owner = "team" }
  }
}

run "new_subscription_gets_subscription_scope" {
  command = plan

  assert {
    condition     = output.settings.mode == "create" && output.settings.access_scope == "subscription"
    error_message = "A request without subscription_id must create a subscription and grant access at subscription scope."
  }

  assert {
    condition     = output.settings.management_group == "mg-corp"
    error_message = "corp must map to the corp management group from platform config."
  }

  assert {
    condition     = contains(output.settings.resource_groups, "NetworkWatcherRG")
    error_message = "New subscriptions must manage NetworkWatcherRG."
  }
}

run "shared_platform_subscription_stays_on_resource_groups" {
  command = plan

  variables {
    request = {
      name            = "team-app-dev"
      archetype       = "corp"
      subscription_id = "11111111-1111-1111-1111-111111111111"
      owners          = ["33333333-3333-3333-3333-333333333333"]
      budget_contacts = ["team@example.com"]
      tags            = { Environment = "Dev", Project = "team-app", CostCentre = "CC-POC", Owner = "team" }
    }
  }

  assert {
    condition     = output.settings.mode == "adopt-shared" && output.settings.access_scope == "resource-groups"
    error_message = "Adopting the platform subscription must keep access on the request's resource groups."
  }

  assert {
    condition     = !contains(output.settings.resource_groups, "NetworkWatcherRG")
    error_message = "An adopted subscription already has NetworkWatcherRG; it must not be created."
  }
}

run "sandbox_never_peers" {
  command = plan

  variables {
    request = {
      name            = "team-lab"
      archetype       = "sandbox"
      owners          = ["33333333-3333-3333-3333-333333333333"]
      budget_contacts = ["team@example.com"]
      network         = { address_space = "10.20.9.0/24", subnets = { app = "10.20.9.0/25" } }
      tags            = { Environment = "Sandbox", Project = "team-lab", CostCentre = "CC-POC", Owner = "team" }
    }
  }

  assert {
    condition     = !output.settings.hub_peering && output.settings.budget_monthly == 5
    error_message = "sandbox must not peer to the hub and must default to its archetype budget."
  }
}

run "rejects_unknown_archetype" {
  command = plan

  variables {
    request = {
      name            = "team-app-dev"
      archetype       = "prod"
      owners          = ["33333333-3333-3333-3333-333333333333"]
      budget_contacts = ["team@example.com"]
      tags            = { Environment = "Dev", Project = "team-app", CostCentre = "CC-POC", Owner = "team" }
    }
  }

  expect_failures = [var.request]
}

run "rejects_missing_tags" {
  command = plan

  variables {
    request = {
      name            = "team-app-dev"
      archetype       = "corp"
      owners          = ["33333333-3333-3333-3333-333333333333"]
      budget_contacts = ["team@example.com"]
      tags            = { Environment = "Dev" }
    }
  }

  expect_failures = [var.request]
}

run "rejects_bad_cidr" {
  command = plan

  variables {
    request = {
      name            = "team-app-dev"
      archetype       = "corp"
      owners          = ["33333333-3333-3333-3333-333333333333"]
      budget_contacts = ["team@example.com"]
      network         = { address_space = "10.20.9.0/33", subnets = { app = "10.20.9.0/25" } }
      tags            = { Environment = "Dev", Project = "team-app", CostCentre = "CC-POC", Owner = "team" }
    }
  }

  expect_failures = [var.request]
}

run "rejects_new_subscription_without_billing_scope" {
  command = plan

  variables {
    billing_scope = null
  }

  expect_failures = [var.billing_scope]
}
