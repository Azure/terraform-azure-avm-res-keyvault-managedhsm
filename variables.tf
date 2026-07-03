# ---------------------------------------------------------------------------------------------------------------------
# Required inputs
# ---------------------------------------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------------------------------------
# Managed HSM configuration
# ---------------------------------------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------------------------------------
# AzAPI controls (TFFR6 / TFFR7)
# ---------------------------------------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------------------------------------
# AVM standard interfaces
# ---------------------------------------------------------------------------------------------------------------------


variable "admin_object_ids" {
  type        = set(string)
  description = <<DESCRIPTION
The Microsoft Entra object IDs of the initial Managed HSM administrators. These principals are placed in the
**Managed HSM Administrator** local (data-plane) role at creation and are the only principals able to download the
security domain to activate the HSM.

> Best practice: supply a single **security group** object ID rather than individual users. Changing this forces a new
resource to be created.
DESCRIPTION
  nullable    = false

  validation {
    condition     = length(var.admin_object_ids) > 0
    error_message = "At least one administrator object ID must be supplied in `admin_object_ids`."
  }
  validation {
    condition     = alltrue([for id in var.admin_object_ids : can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", id))])
    error_message = "Every value in `admin_object_ids` must be a valid GUID."
  }
}

variable "location" {
  type        = string
  description = "Azure region where the Managed HSM should be deployed."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The name of the Managed HSM. Must be globally unique, 3-24 characters, start with a letter, and contain only letters, numbers and hyphens."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.name))
    error_message = "`name` must be 3-24 characters, start with a letter, end with a letter or number, and contain only letters, numbers and hyphens."
  }
}

variable "parent_id" {
  type        = string
  description = "The resource ID of the resource group in which to create the Managed HSM, e.g. `/subscriptions/{sub}/resourceGroups/{rg}`."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a valid resource group resource ID, e.g. `/subscriptions/{sub}/resourceGroups/{rg}`."
  }
}

variable "tenant_id" {
  type        = string
  description = "The Microsoft Entra (Azure AD) tenant ID used to authenticate requests to the Managed HSM."
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "`tenant_id` must be a valid GUID."
  }
}

variable "create_mode" {
  type        = string
  default     = null
  description = "Controls whether the Managed HSM is created fresh (`default`) or recovered from a soft-deleted instance (`recover`). Leave `null` to use the platform default. Changing this forces a new resource to be created."

  validation {
    condition     = var.create_mode == null ? true : contains(["default", "recover"], var.create_mode)
    error_message = "`create_mode` must be either `default` or `recover` when set."
  }
}

variable "diagnostic_settings" {
  type = map(object({
    name = optional(string, null)
    logs = optional(set(object({
      category       = optional(string, null)
      category_group = optional(string, null)
      enabled        = optional(bool, true)
      retention_policy = optional(object({
        days    = optional(number, 0)
        enabled = optional(bool, false)
      }), {})
    })), [])
    metrics = optional(set(object({
      category = optional(string, null)
      enabled  = optional(bool, true)
      retention_policy = optional(object({
        days    = optional(number, 0)
        enabled = optional(bool, false)
      }), {})
    })), [])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of diagnostic settings to create on the Managed HSM (AVM v2 diagnostic-settings schema). The map key is
deliberately arbitrary to avoid issues where map keys may be unknown at plan time. Allowed category / category-group
names are intentionally not constrained, so new categories work without a module release.

- `name` - (Optional) The name of the diagnostic setting. One will be generated if not set.
- `logs` - (Optional) A set of log entries. Each entry sets exactly one of `category` (e.g. `AuditEvent`) or `category_group` (e.g. `allLogs`, `audit`), plus `enabled` and an optional `retention_policy` (`days`, `enabled`).
- `metrics` - (Optional) A set of metric entries, each with `category` (e.g. `AllMetrics`), `enabled` and an optional `retention_policy`.
- `log_analytics_destination_type` - (Optional) `Dedicated` or `AzureDiagnostics`. Defaults to `Dedicated`.
- `workspace_resource_id` - (Optional) The Log Analytics workspace resource ID.
- `storage_account_resource_id` - (Optional) The storage account resource ID.
- `event_hub_authorization_rule_resource_id` - (Optional) The event hub authorization rule resource ID.
- `event_hub_name` - (Optional) The event hub name.
- `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace resource to send diagnostics to.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: `Dedicated`, `AzureDiagnostics`."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings : alltrue([
        for l in v.logs : (l.category != null) != (l.category_group != null)
      ])
    ])
    error_message = "Each log entry must set exactly one of `category` or `category_group`."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
    ])
    error_message = "At least one of `workspace_resource_id`, `storage_account_resource_id`, `event_hub_authorization_rule_resource_id` or `marketplace_partner_resource_id` must be set."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.workspace_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.OperationalInsights/workspaces", v.workspace_resource_id))
    ])
    error_message = "Each `workspace_resource_id` must be a valid Log Analytics workspace resource ID, or null."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.storage_account_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Storage/storageAccounts", v.storage_account_resource_id))
    ])
    error_message = "Each `storage_account_resource_id` must be a valid storage account resource ID, or null."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.event_hub_authorization_rule_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.EventHub/namespaces/authorizationRules", v.event_hub_authorization_rule_resource_id))
    ])
    error_message = "Each `event_hub_authorization_rule_resource_id` must be a valid Event Hub namespace authorization rule resource ID, or null."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for the Managed HSM. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `CanNotDelete` and `ReadOnly`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be one of: `CanNotDelete` or `ReadOnly`."
  }
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Controls the Managed Identity configuration on the Managed HSM. The following properties can be specified:

- `system_assigned` - (Optional) Specifies if the System Assigned Managed Identity should be enabled.
- `user_assigned_resource_ids` - (Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for id in var.managed_identities.user_assigned_resource_ids :
      can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", id))
    ])
    error_message = "Each entry in `managed_identities.user_assigned_resource_ids` must be a valid user-assigned managed identity resource ID."
  }
}

variable "network_acls" {
  type = object({
    bypass                     = optional(string, "AzureServices")
    default_action             = optional(string, "Deny")
    ip_rules                   = optional(list(string), [])
    virtual_network_subnet_ids = optional(list(string), [])
    service_tags               = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Network rules governing access to the Managed HSM. Defaults to a secure posture: deny by default while allowing
trusted Azure services (`bypass = AzureServices`, `default_action = Deny`).

- `bypass` - (Optional) Traffic that can bypass the network rules. Possible values are `AzureServices` and `None`. Defaults to `AzureServices`.
- `default_action` - (Optional) Action when no rule matches. Possible values are `Allow` and `Deny`. Defaults to `Deny`.
- `ip_rules` - (Optional) A list of IPv4 addresses or CIDR ranges allowed to access the Managed HSM. Defaults to `[]`.
- `virtual_network_subnet_ids` - (Optional) A list of subnet resource IDs allowed to access the Managed HSM. Defaults to `[]`.
- `service_tags` - (Optional) A list of service tag names allowed to access the Managed HSM. Defaults to `[]`.

Set this variable to `null` to create the Managed HSM with no network firewall (open to all networks subject to `public_network_access_enabled`).
DESCRIPTION

  validation {
    condition     = var.network_acls == null ? true : contains(["AzureServices", "None"], var.network_acls.bypass)
    error_message = "`network_acls.bypass` must be either `AzureServices` or `None`."
  }
  validation {
    condition     = var.network_acls == null ? true : contains(["Allow", "Deny"], var.network_acls.default_action)
    error_message = "`network_acls.default_action` must be either `Allow` or `Deny`."
  }
}

variable "private_endpoints" {
  type = map(object({
    name = optional(string, null)
    role_assignments = optional(map(object({
      name                                   = optional(string, null)
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
    lock = optional(object({
      kind = string
      name = optional(string, null)
    }), null)
    tags                                    = optional(map(string), null)
    subnet_resource_id                      = string
    subresource_name                        = optional(string, "managedhsm")
    private_dns_zone_group_name             = optional(string, "default")
    private_dns_zone_resource_ids           = optional(set(string), [])
    application_security_group_associations = optional(map(string), {})
    private_service_connection_name         = optional(string, null)
    network_interface_name                  = optional(string, null)
    location                                = optional(string, null)
    resource_group_name                     = optional(string, null)
    ip_configurations = optional(map(object({
      name               = string
      private_ip_address = string
      member_name        = optional(string)
    })), {})
  }))
  default     = {}
  description = <<DESCRIPTION
A map of private endpoints to create on the Managed HSM. The map key is deliberately arbitrary to avoid issues where
map keys may be unknown at plan time. The private endpoint targets the `managedhsm` sub-resource by default.

- `name` - (Optional) The name of the private endpoint. One will be generated if not set.
- `role_assignments` - (Optional) A map of role assignments to create on the private endpoint. See `var.role_assignments`.
- `lock` - (Optional) The lock to apply to the private endpoint.
- `tags` - (Optional) A mapping of tags to assign to the private endpoint. Defaults to `var.tags`.
- `subnet_resource_id` - (Required) The resource ID of the subnet to deploy the private endpoint in.
- `subresource_name` - (Optional) The Managed HSM sub-resource (group ID) to connect to. Defaults to `managedhsm`.
- `private_dns_zone_group_name` - (Optional) The name of the private DNS zone group. Defaults to `default`.
- `private_dns_zone_resource_ids` - (Optional) A set of private DNS zone resource IDs (e.g. `privatelink.managedhsm.azure.net`). If empty, no zone group is created.
- `application_security_group_associations` - (Optional) A map of application security group resource IDs to associate. The map key is arbitrary.
- `private_service_connection_name` - (Optional) The name of the private service connection. One will be generated if not set.
- `network_interface_name` - (Optional) The name of the network interface. One will be generated if not set.
- `location` - (Optional) The location of the private endpoint. Defaults to the Managed HSM location.
- `resource_group_name` - (Optional) The resource group resource ID of the private endpoint. Defaults to the Managed HSM resource group.
- `ip_configurations` - (Optional) A map of static IP configurations (`name`, `private_ip_address`, optional `member_name`). The map key is arbitrary.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, v in var.private_endpoints :
      can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", v.subnet_resource_id))
    ])
    error_message = "Each `private_endpoints[*].subnet_resource_id` must be a valid subnet resource ID."
  }
  validation {
    condition = alltrue(flatten([
      for _, v in var.private_endpoints : [
        for id in v.private_dns_zone_resource_ids :
        can(provider::azapi::parse_resource_id("Microsoft.Network/privateDnsZones", id))
      ]
    ]))
    error_message = "Each entry in `private_endpoints[*].private_dns_zone_resource_ids` must be a valid private DNS zone resource ID."
  }
  validation {
    condition = alltrue(flatten([
      for _, v in var.private_endpoints : [
        for _, asg in v.application_security_group_associations :
        can(provider::azapi::parse_resource_id("Microsoft.Network/applicationSecurityGroups", asg))
      ]
    ]))
    error_message = "Each value in `private_endpoints[*].application_security_group_associations` must be a valid application security group resource ID."
  }
}

variable "private_endpoints_manage_dns_zone_group" {
  type        = bool
  default     = true
  description = "Whether to manage private DNS zone groups with this module. If set to `false`, you must manage private DNS zone groups externally, e.g. using Azure Policy."
  nullable    = false
}

variable "public_network_access_enabled" {
  type        = bool
  default     = true
  description = "Whether traffic from public networks is permitted. When `true`, access is still governed by `network_acls`. Defaults to `true`."
  nullable    = false
}

variable "purge_protection_enabled" {
  type        = bool
  default     = true
  description = "Whether purge protection is enabled. When enabled, only the Managed HSM service may perform an irrecoverable deletion after the soft-delete retention period. Enabling this is irreversible. Defaults to `true`. Changing this forces a new resource to be created."
  nullable    = false
}

variable "regions" {
  type = list(object({
    name       = string
    is_primary = optional(bool)
  }))
  default     = []
  description = <<DESCRIPTION
Optional list of regions for Managed HSM **multi-region (geo-replicated)** deployments. Leave empty for a
single-region HSM (the `location` region is used). Each object supports:

- `name` - (Required) The Azure region name of the replica.
- `is_primary` - (Optional) Whether the region is the primary region.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    keyvault_managed_hsms = optional(string, "Microsoft.KeyVault/managedHSMs@2026-02-01")
    authorization_locks   = optional(string, "Microsoft.Authorization/locks@2020-05-01")
  })
  default     = {}
  description = <<DESCRIPTION
The AzAPI `<provider>/<resource>@<api-version>` strings used by this module. Keys follow the AVM naming rule
(snake_case ARM type with the `Microsoft.` prefix dropped). Override only to pin a different, tested API version.

- `keyvault_managed_hsms` - The Managed HSM pool. Defaults to a tested stable API version.
- `authorization_locks` - The management lock applied to the Managed HSM. Defaults to a tested stable API version.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration applied to every AzAPI resource managed by the module. Leave `null` for no custom retry.

- `error_message_regex` - (Optional) A list of regular expressions matched against the error message to decide whether to retry.
- `interval_seconds` - (Optional) The base number of seconds to wait between retries.
- `max_interval_seconds` - (Optional) The maximum number of seconds to wait between retries.
DESCRIPTION
}

variable "role_assignment_definition_lookup_enabled" {
  type        = bool
  default     = true
  description = "Whether the `Azure/avm-utl-interfaces/azure` module should resolve role definition names supplied via `role_definition_id_or_name` by querying the Azure Authorization API. Set to `false` if you only ever supply fully-qualified role definition resource IDs (e.g. in air-gapped or permission-restricted environments)."
  nullable    = false
}

variable "role_assignments" {
  type = map(object({
    name                                   = optional(string, null)
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of **Azure RBAC (control-plane)** role assignments to create on the Managed HSM. The map key is deliberately
arbitrary to avoid issues where map keys may be unknown at plan time.

> [!NOTE]
> These are management-plane (ARM) role assignments scoped to the HSM resource (for example `Managed HSM Contributor`).
> They are **not** the HSM **local / data-plane RBAC** roles (`Managed HSM Administrator`, `Managed HSM Crypto User`,
> etc.), which are assigned via the data plane after activation and are out of scope for this module.

- `name` - (Optional) The name of the role assignment. If not set, a GUID will be generated.
- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - (Optional) The description of the role assignment.
- `skip_service_principal_aad_check` - (Optional) If set to true, skips the Microsoft Entra check for the service principal in the tenant. Defaults to false.
- `condition` - (Optional) The condition which will be used to scope the role assignment.
- `condition_version` - (Optional) The version of the condition syntax. Valid values are `2.0`.
- `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource ID which contains a Managed Identity. Changing this forces a new resource to be created.
- `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, v in var.role_assignments :
      v.delegated_managed_identity_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", v.delegated_managed_identity_resource_id))
    ])
    error_message = "Each `role_assignments[*].delegated_managed_identity_resource_id` must be a valid user-assigned managed identity resource ID, or null."
  }
}

variable "schema_validation_enabled" {
  type        = bool
  default     = true
  description = "Whether to enable AzAPI request body schema validation against the pinned API version. Defaults to `true`."
  nullable    = false
}

variable "sku_name" {
  type        = string
  default     = "Standard_B1"
  description = "The SKU of the Managed HSM pool. Possible values are `Standard_B1`, `Custom_B6`, `Custom_B32`, `Custom_C10` and `Custom_C42`. Changing this forces a new resource to be created."
  nullable    = false

  validation {
    condition     = contains(["Standard_B1", "Custom_B6", "Custom_B32", "Custom_C10", "Custom_C42"], var.sku_name)
    error_message = "`sku_name` must be one of: `Standard_B1`, `Custom_B6`, `Custom_B32`, `Custom_C10`, `Custom_C42`."
  }
}

variable "soft_delete_retention_days" {
  type        = number
  default     = 90
  description = "The number of days that the Managed HSM (and its keys) are retained once soft-deleted. Must be between 7 and 90. Defaults to 90. Changing this forces a new resource to be created."
  nullable    = false

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "`soft_delete_retention_days` must be between 7 and 90."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Map of tags to assign to the Managed HSM resource."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Per-operation timeouts applied to every AzAPI resource managed by the module. Defaults to `null` (provider
defaults). Each value is a Go duration string (e.g. `30m`, `1h`).

- `create` - (Optional) Timeout for create operations.
- `read` - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
