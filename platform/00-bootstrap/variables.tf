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
  default     = "rohan-caizin@236310955/azure-subscription-vending-poc@1446656004"
  description = <<-EOT
    Repository part of the GitHub OIDC "sub" claim, exactly as GitHub presents it.
    This repo uses GitHub's immutable-ID subject format (owner@ownerId/repo@repoId), which
    survives renames. Older repos use plain owner/repo. If login fails with AADSTS700213,
    copy the subject from the error message.
  EOT

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+(@[0-9]+)?/[A-Za-z0-9._-]+(@[0-9]+)?$", var.github_repo))
    error_message = "github_repo must be owner/repository or owner@ownerId/repository@repoId."
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

variable "billing_scope" {
  type        = string
  default     = null
  description = "MCA invoice section on which the apply identity gets the Azure subscription creator role (billing.tf). null = skip."

  validation {
    condition     = var.billing_scope == null || can(regex("^/providers/Microsoft\\.Billing/billingAccounts/[^/]+/billingProfiles/[^/]+/invoiceSections/[^/]+$", var.billing_scope))
    error_message = "billing_scope must be an MCA invoice section ID."
  }
}
