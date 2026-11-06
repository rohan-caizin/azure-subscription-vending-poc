# Archetypes: named presets for each kind of landing zone.
# The archetype picks the management group (config/platform.yaml), which decides the
# inherited policies. Add an archetype here AND in platform/10-core + config/platform.yaml.
locals {
  archetypes = {
    corp = {
      hub_peering    = true
      budget_default = 10
      owner_role     = "Contributor"
      deploy_role    = "Contributor"
    }
    sandbox = {
      hub_peering    = false
      budget_default = 5
      owner_role     = "Contributor"
      deploy_role    = "Contributor"
    }
  }

  # Workload type of NEW subscriptions. An individual MCA account has no Dev/Test
  # offer, so "DevTest" would fail at creation; use it only on EA / enterprise MCA.
  workload = "Production"

  # Resource providers registered on NEW subscriptions only. The platform
  # subscription had its providers registered during bootstrap.
  resource_providers = {
    "Microsoft.Compute"             = []
    "Microsoft.Consumption"         = []
    "Microsoft.CostManagement"      = []
    "Microsoft.Insights"            = []
    "Microsoft.KeyVault"            = []
    "Microsoft.ManagedIdentity"     = []
    "Microsoft.Network"             = []
    "Microsoft.OperationalInsights" = []
    "Microsoft.Storage"             = []
  }

  archetype        = local.archetypes[var.request.archetype]
  management_group = var.platform.management_groups[var.request.archetype]
  name             = var.request.name

  # create    : no subscription_id -> a new subscription through the Subscription Alias API
  # dedicated : the landing zone owns its whole subscription (created, or adopted and not
  #             the platform subscription) -> access is granted at subscription scope.
  #             Otherwise it shares the platform subscription -> access stays on its own
  #             resource groups.
  create    = var.request.subscription_id == null
  dedicated = var.request.subscription_id != var.platform.platform_subscription_id

  tags = merge(var.platform.default_tags, var.request.tags)
}
