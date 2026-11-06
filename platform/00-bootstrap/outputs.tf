output "tenant_id" {
  description = "GitHub variable AZURE_TENANT_ID."
  value       = azurerm_user_assigned_identity.pipeline["plan"].tenant_id
}

output "plan_client_id" {
  description = "GitHub variable ARM_CLIENT_ID_PLAN."
  value       = azurerm_user_assigned_identity.pipeline["plan"].client_id
}

output "apply_client_id" {
  description = "GitHub variable ARM_CLIENT_ID_APPLY."
  value       = azurerm_user_assigned_identity.pipeline["apply"].client_id
}

output "plan_principal_id" {
  description = "Object ID of the plan identity (read by platform/10-core/rbac.tf)."
  value       = azurerm_user_assigned_identity.pipeline["plan"].principal_id
}

output "apply_principal_id" {
  description = "Object ID of the apply identity (read by platform/10-core/rbac.tf)."
  value       = azurerm_user_assigned_identity.pipeline["apply"].principal_id
}

output "federated_subjects" {
  description = "GitHub OIDC subjects trusted per identity."
  value       = { for k, v in azurerm_federated_identity_credential.github : k => v.subject }
}
