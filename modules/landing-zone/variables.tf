variable "platform" {
  type = object({
    location                 = string
    platform_subscription_id = string
    management_groups        = map(string)
    hub_vnet_id              = string
    hub_has_gateway          = bool
    budget_start             = string
    budget_end               = string
    default_tags             = map(string)
  })
  description = "Platform-wide values from config/platform.yaml."
}

variable "billing_scope" {
  type        = string
  default     = null
  description = "Billing scope (MCA invoice section, EA enrollment account) that pays for NEW subscriptions. Only needed by requests without subscription_id."

  validation {
    condition     = var.request.subscription_id != null || can(regex("^/providers/Microsoft\\.Billing/billingAccounts/.+", var.billing_scope))
    error_message = "This request creates a new subscription, so billing_scope is required (CI: GitHub variable BILLING_SCOPE)."
  }
}

variable "request" {
  type = object({
    name                    = string
    display_name            = optional(string)
    archetype               = string
    subscription_id         = optional(string) # adopt an existing subscription instead of creating one
    manage_management_group = optional(bool, true)
    owners                  = list(string)
    budget_monthly          = optional(number)
    budget_start            = optional(string)
    budget_contacts         = list(string)
    network = optional(object({
      address_space = string
      subnets       = optional(map(string), {})
    }))
    github_repo = optional(string)
    tags        = map(string)
  })
  description = "One subscription request, decoded from its YAML file."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$", var.request.name))
    error_message = "name must be 3-40 characters: lowercase letters, digits and hyphens, not starting or ending with a hyphen."
  }

  validation {
    condition     = contains(["corp", "sandbox"], var.request.archetype)
    error_message = "archetype must be one of: corp, sandbox."
  }

  validation {
    condition     = var.request.subscription_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.request.subscription_id))
    error_message = "subscription_id must be a lowercase GUID, or omitted to create a new subscription."
  }

  validation {
    condition     = length(var.request.owners) > 0 && alltrue([for id in var.request.owners : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))])
    error_message = "owners must list at least one Entra group object ID (lowercase GUID)."
  }

  validation {
    condition     = length(var.request.budget_contacts) > 0 && alltrue([for e in var.request.budget_contacts : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "budget_contacts must list at least one email address."
  }

  validation {
    condition     = var.request.budget_monthly == null || try(var.request.budget_monthly > 0 && var.request.budget_monthly <= 100, false)
    error_message = "budget_monthly must be between 0 and 100 in the PoC."
  }

  validation {
    condition     = var.request.budget_start == null || can(regex("^\\d{4}-\\d{2}-01T00:00:00Z$", var.request.budget_start))
    error_message = "budget_start must be the first day of a month, e.g. 2026-12-01T00:00:00Z."
  }

  validation {
    condition = var.request.network == null || try(
      cidrhost(var.request.network.address_space, 0) != "" &&
      alltrue([for p in values(var.request.network.subnets) : cidrhost(p, 0) != ""]),
      false
    )
    error_message = "network.address_space and every network.subnets value must be valid CIDRs, e.g. 10.20.5.0/24."
  }

  validation {
    condition     = var.request.network == null || try(length(var.request.network.subnets) > 0, false)
    error_message = "network.subnets must list at least one subnet."
  }

  validation {
    condition     = var.request.github_repo == null || can(regex("^[A-Za-z0-9-]+(@[0-9]+)?/[A-Za-z0-9._-]+(@[0-9]+)?$", var.request.github_repo))
    error_message = "github_repo must be owner/repository, or owner@ownerId/repository@repoId if the repo uses GitHub's immutable-ID OIDC subjects."
  }

  validation {
    condition     = alltrue([for t in ["Environment", "Project", "CostCentre", "Owner"] : contains(keys(var.request.tags), t)])
    error_message = "tags must include Environment, Project, CostCentre and Owner."
  }

  validation {
    condition     = can(regex("^CC-[A-Z0-9-]+$", try(var.request.tags["CostCentre"], "")))
    error_message = "tags.CostCentre must look like CC-XXXX."
  }
}
