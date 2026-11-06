# Plans the real request files against mocked providers: no Azure login needed.
# Run from stacks/subscription:  terraform init -backend=false && terraform test

mock_provider "azapi" {
  mock_data "azapi_resource_list" {
    defaults = {
      output = { value = [] }
    }
  }

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
  billing_scope = "/providers/Microsoft.Billing/billingAccounts/a/billingProfiles/b/invoiceSections/c"
  legacy_import = false # mock providers cannot import; remove with migrate.tf
}

run "poc_app1_dev_shares_platform_subscription" {
  command = plan

  variables {
    request_file = "../../subscriptions/app1/poc-app1-dev.yaml"
  }

  assert {
    condition     = output.settings.mode == "adopt-shared" && output.settings.access_scope == "resource-groups"
    error_message = "poc-app1-dev lives in the platform subscription; access must stay on its resource groups."
  }

  assert {
    condition     = output.settings.management_group == "caizin-poc-corp" && output.settings.hub_peering
    error_message = "poc-app1-dev must be corp and peer to the hub."
  }

  assert {
    condition     = output.settings.deploy_identity
    error_message = "poc-app1-dev must keep its GitHub deploy identity."
  }
}

run "poc_sandbox_01_creates_subscription" {
  command = plan

  variables {
    request_file = "../../subscriptions/platform/poc-sandbox-01.yaml"
  }

  assert {
    condition     = output.settings.mode == "create" && output.settings.management_group == "caizin-poc-sandbox"
    error_message = "poc-sandbox-01 must create a new subscription in the sandbox management group."
  }

  assert {
    condition     = !output.settings.hub_peering && !output.settings.deploy_identity
    error_message = "poc-sandbox-01 has no network and no deploy identity."
  }
}
