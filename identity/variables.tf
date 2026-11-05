variable "subscription_id" {
  type        = string
  description = "Subscription that hosts the identities and receives the pipeline role assignments."
}

variable "location" {
  type        = string
  default     = "centralindia"
  description = "Region for the identity resource group."
}

variable "github_repo" {
  type        = string
  default     = "rohan-caizin/azure-subscription-vending-poc"
  description = "GitHub repository (owner/name) trusted by the OIDC federated credentials. Must match exactly."

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must be in the form owner/repository."
  }
}

variable "apply_environment" {
  type        = string
  default     = "poc-apply"
  description = "GitHub environment (with required reviewers) whose jobs may use the apply identity."
}

variable "state" {
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
  })
  default = {
    resource_group_name  = "rg-tfstate-poc"
    storage_account_name = "sttfstatepoc21602"
    container_name       = "tfstate"
  }
  description = "Terraform state storage the pipeline identities need data access to."
}

variable "tags" {
  type = map(string)
  default = {
    CostCentre  = "CC-POC"
    Environment = "Platform"
    Owner       = "poc"
  }
  description = "Tags for the identity resource group and identities."
}
