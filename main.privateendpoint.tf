# AVM interface: private endpoints (rendered to AzAPI bodies by the avm_interfaces utility module).
resource "azapi_resource" "private_endpoints" {
  for_each = module.avm_interfaces.private_endpoints_azapi

  location               = coalesce(var.private_endpoints[each.key].location, var.location)
  name                   = each.value.name
  parent_id              = coalesce(var.private_endpoints[each.key].resource_group_name, local.resource_group_id)
  type                   = each.value.type
  body                   = each.value.body
  replace_triggers_refs  = []
  response_export_values = []
  retry                  = var.retry
  tags                   = each.value.tags != null ? each.value.tags : var.tags

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

resource "azapi_resource" "private_dns_zone_groups" {
  for_each = module.avm_interfaces.private_dns_zone_groups_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.private_endpoints[each.key].id
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

resource "azapi_resource" "private_endpoint_role_assignments" {
  for_each = module.avm_interfaces.role_assignments_private_endpoint_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.private_endpoints[each.value.pe_key].id
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

resource "azapi_resource" "private_endpoint_locks" {
  for_each = module.avm_interfaces.lock_private_endpoint_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.private_endpoints[each.value.pe_key].id
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

  depends_on = [
    azapi_resource.private_dns_zone_groups,
    azapi_resource.private_endpoint_role_assignments,
  ]
}
