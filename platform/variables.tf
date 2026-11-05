variable "subscription_id" {
  type        = string
  description = "Subscription that hosts the platform resources (hub VNet). In single-subscription PoC mode this is also the vended subscription."
}

variable "location" {
  type        = string
  default     = "centralindia"
  description = "Region for platform resources."
}

variable "allowed_locations" {
  type        = list(string)
  default     = ["centralindia"]
  description = "Regions allowed by policy across the caizin-poc hierarchy."
}

variable "hub_address_space" {
  type        = list(string)
  default     = ["10.100.0.0/22"]
  description = "Address space of the hub VNet. Must not overlap any spoke (10.20.0.0/16)."
}

variable "tags" {
  type = map(string)
  default = {
    CostCentre  = "CC-POC"
    Environment = "Platform"
    Owner       = "poc"
  }
  description = "Tags applied to platform resource groups."
}
