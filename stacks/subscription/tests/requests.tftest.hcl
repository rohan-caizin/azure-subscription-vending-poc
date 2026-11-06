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

mock_provider "azuread" {
  mock_data "azuread_users" {
    defaults = {
      object_ids = ["00000000-0000-0000-0000-0000000000e1"]
    }
  }
}

variables {
  billing_scope = "/providers/Microsoft.Billing/billingAccounts/a/billingProfiles/b/invoiceSections/c"
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
    condition     = output.settings.management_group == "(not managed by this request)" && output.settings.hub_peering
    error_message = "poc-app1-dev must leave the platform subscription's management group to platform/10-core and peer to the hub."
  }

  assert {
    condition     = output.settings.access.owners.group == "grp-lz-poc-app1-dev-owners"
    error_message = "poc-app1-dev owners must be managed in grp-lz-poc-app1-dev-owners."
  }

  assert {
    condition     = output.settings.deploy_identity
    error_message = "poc-app1-dev must keep its GitHub deploy identity."
  }
}
