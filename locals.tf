locals {
  # Managed HSM SKU family is derived from the SKU name (C-family for Custom_C*, otherwise B-family).
  sku_family = startswith(var.sku_name, "Custom_C") ? "C" : "B"

  # The resource group ID (== parent_id), reused as the default parent scope for private endpoints.
  resource_group_id = var.parent_id


  # Normalise `managed_identities` into the AzAPI `identity` block `type`. Computed locally (rather than
  # via the avm_interfaces module) to avoid a dependency cycle: avm_interfaces is scoped to
  # azapi_resource.this.id, so azapi_resource.this must not depend on avm_interfaces.
  managed_identity_type = (var.managed_identities.system_assigned || length(var.managed_identities.user_assigned_resource_ids) > 0) ? (
    (var.managed_identities.system_assigned && length(var.managed_identities.user_assigned_resource_ids) > 0) ? "SystemAssigned, UserAssigned" : (
      length(var.managed_identities.user_assigned_resource_ids) > 0 ? "UserAssigned" : "SystemAssigned"
    )
  ) : null
}
