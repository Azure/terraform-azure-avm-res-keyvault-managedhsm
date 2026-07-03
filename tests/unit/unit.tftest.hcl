mock_provider "azapi" {
  # Give the mocked Managed HSM (and the avm_interfaces scopes) a valid ARM resource ID.
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit-test/providers/Microsoft.KeyVault/managedHSMs/mhsmunittest01"
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  location         = "eastus"
  name             = "mhsmunittest01"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit-test"
  tenant_id        = "00000000-0000-0000-0000-000000000000"
  admin_object_ids = ["11111111-1111-1111-1111-111111111111"]
  # Supply role definition IDs directly so the avm_interfaces role-definition lookup is not exercised under mocks.
  role_assignment_definition_lookup_enabled = false
}

run "default_creates_hsm_and_telemetry" {
  command = apply

  assert {
    condition     = azapi_resource.this.name == var.name
    error_message = "The Managed HSM resource name should match var.name."
  }
  assert {
    condition     = azapi_resource.this.type == "Microsoft.KeyVault/managedHSMs@2026-02-01"
    error_message = "The Managed HSM should default to the pinned stable API version."
  }
  assert {
    condition     = length(modtm_telemetry.telemetry) == 1
    error_message = "Telemetry resource should be created when enable_telemetry is true (default)."
  }
  assert {
    condition     = length(azapi_resource.lock) == 0
    error_message = "No lock should be created when var.lock is null."
  }
}

run "telemetry_disabled" {
  command = apply

  variables {
    enable_telemetry = false
  }

  assert {
    condition     = length(modtm_telemetry.telemetry) == 0
    error_message = "Telemetry resource should not be created when enable_telemetry is false."
  }
}

run "lock_and_role_assignment_created" {
  command = apply

  variables {
    lock = {
      kind = "CanNotDelete"
    }
    role_assignments = {
      contributor = {
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/18d7d88d-d35e-4fb5-a5c3-7773c20a72d9"
        principal_id               = "22222222-2222-2222-2222-222222222222"
      }
    }
  }

  assert {
    condition     = length(azapi_resource.lock) == 1
    error_message = "A management lock should be created when var.lock is set."
  }
  assert {
    condition     = length(azapi_resource.role_assignments) == 1
    error_message = "A role assignment should be created for each entry in var.role_assignments."
  }
}

run "invalid_name_is_rejected" {
  command = plan

  variables {
    name = "1-invalid"
  }

  expect_failures = [var.name]
}

run "empty_admins_rejected" {
  command = plan

  variables {
    admin_object_ids = []
  }

  expect_failures = [var.admin_object_ids]
}
