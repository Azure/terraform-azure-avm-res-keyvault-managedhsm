# terraform-azure-avm-res-keyvault-managedhsm

This is an [Azure Verified Module (AVM)](https://aka.ms/avm) **resource module** for **Azure Key Vault Managed HSM** (`Microsoft.KeyVault/managedHSMs`), built on the **AzAPI** provider. It deploys and configures the Managed HSM **pool** (the control-plane resource) and its standard ARM extension resources.

> [!IMPORTANT]
> This module manages the **control-plane** Managed HSM pool and its ARM extension resources (resource lock, Azure RBAC role assignments, diagnostic settings, private endpoints, managed identity). The **data-plane** activation (the *security-domain ceremony*), the **local RBAC** roles (`Managed HSM Administrator`, `Managed HSM Crypto User`, `Managed HSM Crypto Service Encryption User`), and **keys** are deliberately **out of scope** — they are customer-owned, offline/manual operations and cannot be managed through ARM/AzAPI. See [Data-plane scope](#data-plane-scope-not-managed-by-this-module).

> [!NOTE]
> A `Standard_B1` Managed HSM bills **continuously (~US$2.5k/month)** from the moment it is created, regardless of usage or activation state. Provision it only when you are ready to use it.
