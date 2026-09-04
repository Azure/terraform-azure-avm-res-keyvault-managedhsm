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

# Randomise the region so concurrent example runs do not collide.
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

# Managed HSM names are globally unique; a short random suffix keeps the example idempotent across runs.
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

module "managed_hsm" {
  source = "../../"

  # In a real deployment, supply a SECURITY GROUP object ID rather than the current user.
  admin_object_ids = [data.azurerm_client_config.current.object_id]
  location         = azurerm_resource_group.this.location
  name             = "mhsm${random_string.suffix.result}"
  parent_id        = azurerm_resource_group.this.id
  tenant_id        = data.azurerm_client_config.current.tenant_id
  enable_telemetry = var.enable_telemetry
}
