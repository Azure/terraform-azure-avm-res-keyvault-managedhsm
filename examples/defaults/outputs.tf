output "hsm_uri" {
  description = "The data-plane URI of the Managed HSM (used for the activation ceremony and key operations)."
  value       = module.managed_hsm.hsm_uri
}

output "resource_id" {
  description = "The Azure resource ID of the Managed HSM."
  value       = module.managed_hsm.resource_id
}
