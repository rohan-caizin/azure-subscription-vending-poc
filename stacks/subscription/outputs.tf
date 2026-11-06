output "settings" {
  description = "Resolved archetype settings for this request."
  value       = module.landing_zone.settings
}

output "subscription_id" {
  description = "ID of the vended (or adopted) subscription."
  value       = module.landing_zone.subscription_id
}

output "deploy_identity" {
  description = "Client and tenant IDs to configure in the app team's GitHub repo."
  value       = module.landing_zone.deploy_identity
}
