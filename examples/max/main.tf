terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.12.0"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

# --- Supporting infrastructure: network + DNS + monitoring -----------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "pe" {
  name                 = "snet-pe"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.0.0/27"]
}

resource "azurerm_private_dns_zone" "managedhsm" {
  name                = "privatelink.managedhsm.azure.net"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "dnslink-managedhsm"
  private_dns_zone_name = azurerm_private_dns_zone.managedhsm.name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = azurerm_virtual_network.this.id
}

resource "azurerm_log_analytics_workspace" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_user_assigned_identity" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this.name
}

# --- The Managed HSM module, exercising the standard AVM interfaces ---------------------------------------------------

module "managed_hsm" {
  source = "../../"

  admin_object_ids = [data.azurerm_client_config.current.object_id]
  location         = azurerm_resource_group.this.location
  name             = "mhsm${random_string.suffix.result}"
  parent_id        = azurerm_resource_group.this.id
  tenant_id        = data.azurerm_client_config.current.tenant_id
  diagnostic_settings = {
    audit = {
      name                  = "diag-to-law"
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
      logs                  = [{ category = "AuditEvent" }]
      metrics               = [{ category = "AllMetrics" }]
    }
  }
  enable_telemetry = var.enable_telemetry
  lock = {
    kind = "CanNotDelete"
  }
  managed_identities = {
    user_assigned_resource_ids = [azurerm_user_assigned_identity.this.id]
  }
  network_acls = {
    bypass         = "AzureServices"
    default_action = "Deny"
  }
  private_endpoints = {
    primary = {
      subnet_resource_id            = azurerm_subnet.pe.id
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.managedhsm.id]
    }
  }
  # Locked-down network: deny by default, allow trusted Azure services (e.g. service CMK paths).
  public_network_access_enabled = true
  role_assignments = {
    # Control-plane (Azure RBAC) example — NOT a local/data-plane HSM role.
    reader = {
      role_definition_id_or_name = "Reader"
      principal_id               = data.azurerm_client_config.current.object_id
      principal_type             = "User"
    }
  }
  tags = {
    environment = "example"
    workload    = "managed-hsm"
  }
}
