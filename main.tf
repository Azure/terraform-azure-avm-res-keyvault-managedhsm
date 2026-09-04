resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.keyvault_managed_hsms
  body = {
    sku = {
      family = local.sku_family
      name   = var.sku_name
    }
    properties = merge(
      {
        tenantId                  = var.tenant_id
        initialAdminObjectIds     = tolist(var.admin_object_ids)
        enableSoftDelete          = true
        softDeleteRetentionInDays = var.soft_delete_retention_days
        enablePurgeProtection     = var.purge_protection_enabled
        publicNetworkAccess       = var.public_network_access_enabled ? "Enabled" : "Disabled"
      },
      var.create_mode == null ? {} : { createMode = var.create_mode },
      var.network_acls == null ? {} : {
        networkAcls = merge(
          {
            bypass              = var.network_acls.bypass
            defaultAction       = var.network_acls.default_action
            ipRules             = [for ip in var.network_acls.ip_rules : { value = ip }]
            virtualNetworkRules = [for subnet_id in var.network_acls.virtual_network_subnet_ids : { id = subnet_id }]
          },
          length(var.network_acls.service_tags) == 0 ? {} : {
            serviceTags = [for tag in var.network_acls.service_tags : { tag = tag }]
          }
        )
      },
      length(var.regions) == 0 ? {} : {
        regions = [for region in var.regions : merge(
          { name = region.name },
          region.is_primary == null ? {} : { isPrimary = region.is_primary }
        )]
      }
    )
  }
  # `name` and `location` are implicit replace triggers; list only the immutable body paths (TFFR5).
  replace_triggers_refs = [
    "sku.name",
    "properties.tenantId",
    "properties.initialAdminObjectIds",
    "properties.createMode",
    "properties.enableSoftDelete",
    "properties.softDeleteRetentionInDays",
    "properties.enablePurgeProtection",
  ]
  response_export_values    = ["properties.hsmUri", "properties.provisioningState"]
  retry                     = var.retry
  schema_validation_enabled = var.schema_validation_enabled
  tags                      = var.tags

  dynamic "identity" {
    for_each = local.managed_identity_type == null ? [] : [local.managed_identity_type]

    content {
      type         = identity.value
      identity_ids = var.managed_identities.user_assigned_resource_ids
    }
  }

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

# Renders the standard AVM interface inputs (role assignments, diagnostic settings, private endpoints)
# into AzAPI resource bodies. Scoped to azapi_resource.this.id, so this module must not feed back into
# azapi_resource.this (managed identity is therefore computed locally - see locals.tf).
module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.6.0"

  diagnostic_settings_v2 = var.diagnostic_settings
  enable_telemetry       = var.enable_telemetry
  private_endpoints = {
    for k, v in var.private_endpoints : k => merge(v, { subresource_name = "managedhsm" })
  }
  private_endpoints_manage_dns_zone_group   = var.private_endpoints_manage_dns_zone_group
  private_endpoints_scope                   = azapi_resource.this.id
  role_assignment_definition_lookup_enabled = var.role_assignment_definition_lookup_enabled
  role_assignment_definition_scope          = azapi_resource.this.id
  role_assignments                          = var.role_assignments
}

# AVM interface: management lock.
resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name      = coalesce(var.lock.name, "lock-${var.lock.kind}")
  parent_id = azapi_resource.this.id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = var.lock.kind
      notes = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
    }
  }
  replace_triggers_refs  = []
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  # Create the lock last and destroy it first, so a CanNotDelete/ReadOnly lock does not block
  # teardown of the HSM-scoped child resources (role assignments, diagnostic settings).
  depends_on = [
    azapi_resource.diagnostic_settings,
    azapi_resource.role_assignments,
  ]
}

# AVM interface: Azure RBAC (control-plane) role assignments on the Managed HSM scope.
resource "azapi_resource" "role_assignments" {
  for_each = module.avm_interfaces.role_assignments_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.this.id
  type                   = each.value.type
  body                   = each.value.body
  replace_triggers_refs  = []
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}
