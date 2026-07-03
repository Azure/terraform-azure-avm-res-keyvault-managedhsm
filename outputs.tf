output "hsm_uri" {
  description = "The data-plane URI of the Managed HSM (e.g. `https://<name>.managedhsm.azure.net`), used for key operations and the security-domain activation ceremony."
  value       = try(azapi_resource.this.output.properties.hsmUri, null)
}

output "name" {
  description = "The name of the Managed HSM."
  value       = azapi_resource.this.name
}

output "private_endpoints" {
  description = "A map of the private endpoints created. The map key is the supplied input to `var.private_endpoints`."
  value       = azapi_resource.private_endpoints
}

output "resource" {
  description = "The Managed HSM resource, including the exported read-only values (`properties.hsmUri`, `properties.provisioningState`)."
  value       = azapi_resource.this.output
}

output "resource_id" {
  description = "The Azure resource ID of the Managed HSM."
  value       = azapi_resource.this.id
}

output "system_assigned_mi_principal_id" {
  description = "The principal ID of the system-assigned managed identity, if enabled."
  value       = try(azapi_resource.this.identity[0].principal_id, null)
}
