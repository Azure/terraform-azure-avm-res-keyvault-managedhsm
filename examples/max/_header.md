# Max example

This deploys the module exercising the standard AVM interfaces:

- a locked-down **network ACL** posture (deny by default, trusted Azure services allowed);
- a **private endpoint** to the `managedhsm` sub-resource, with an in-module private DNS zone group (`privatelink.managedhsm.azure.net`);
- **diagnostic settings** (`AuditEvent` logs + metrics) to a Log Analytics workspace;
- a **user-assigned managed identity**;
- a **resource lock** (`CanNotDelete`);
- a **control-plane Azure RBAC** role assignment (`Managed HSM Contributor`);
- **tags**.

> [!IMPORTANT]
> As with the default example, the Managed HSM is **provisioned but not activated** after apply. The local/data-plane
> RBAC roles and the security-domain ceremony are out of scope — see the module README
> ([Data-plane scope](../../README.md#data-plane-scope-not-managed-by-this-module)).

> [!NOTE]
> A `Standard_B1` Managed HSM bills continuously (~US$2.5k/month) from creation. Destroy the example when you are done.
