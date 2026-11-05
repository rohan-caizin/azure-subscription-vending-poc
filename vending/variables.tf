variable "subscription_id" {
  type        = string
  description = <<-EOT
    Default existing subscription adopted by each landing zone (single-subscription PoC mode:
    a free account cannot create subscriptions by API). A request file may override it
    with its own `subscription_id`.
  EOT

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase GUID."
  }
}

variable "hub_vnet_id" {
  type        = string
  description = "Resource ID of the hub VNet (platform output hub_vnet_id). Spokes peer to it."
}
