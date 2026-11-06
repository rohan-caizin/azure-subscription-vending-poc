variable "request_file" {
  type        = string
  description = "Path to one subscription request YAML file (subscriptions/<team>/<name>.yaml)."
}

variable "platform_file" {
  type        = string
  default     = "../../config/platform.yaml"
  description = "Path to the platform config, relative to this directory."
}

variable "billing_scope" {
  type        = string
  default     = null
  description = "Billing scope for NEW subscriptions. CI sets TF_VAR_billing_scope from the GitHub variable BILLING_SCOPE."
}

locals {
  platform = yamldecode(file(var.platform_file))
  request  = yamldecode(file(var.request_file))
}

module "landing_zone" {
  source = "../../modules/landing-zone"

  platform      = local.platform
  request       = local.request
  billing_scope = var.billing_scope
}
