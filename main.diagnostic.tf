# AVM interface: diagnostic settings (rendered to AzAPI bodies by the avm_interfaces utility module).
resource "azapi_resource" "diagnostic_settings" {
  for_each = module.avm_interfaces.diagnostic_settings_azapi_v2

  name                 = each.value.name
  parent_id            = azapi_resource.this.id
  type                 = each.value.type
  body                 = each.value.body
  ignore_null_property = true
  ignore_other_items_in_list = [
    "properties.logs",
    "properties.metrics",
  ]
  list_unique_id_property = {
    "properties.logs"    = "category, categoryGroup"
    "properties.metrics" = "category"
  }
  replace_triggers_refs     = []
  response_export_values    = []
  retry                     = var.retry
  schema_validation_enabled = false

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
