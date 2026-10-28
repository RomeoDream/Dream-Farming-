# Second Life UUID registration

All new farm registrations use real SL UUIDs. Names are display labels. An SL UUID identifies a record; it does not replace authentication.

| Identity | Source | Behavior |
|---|---|---|
| Owner UUID | `llGetOwner()` | Farm ownership lookup; administrator approves the supplied owner identity |
| Farm UUID | First registration root's object UUID | Persisted farm identity; reuse it when joining additional controllers |
| Controller UUID | Current root `llGetKey()` | Each registered controller has its own UUID and credential |
| Animal UUID | Existing Herd animal record ID | Existing persistent animal identities remain unchanged |

The persisted Farm UUID remains the farm's identity after re-rez; the current root-object UUID is a separate controller identity. Re-rez, copying or changing owner does not silently transfer an old controller credential. Owner changes and unresolved transactions require explicit reconciliation. Display names are never ownership proof. Group-owned objects return the group UUID from llGetOwner; individual avatar ownership is the tested path.

## In-world flow

1. Install generated `lsl/DreamFarm_Register.lsl` in the root beside the existing controller, or alone in a fresh farm-registration prim.
2. With a controller, open **Settings → SL register**. The Stable uses **More → SL register**. A standalone registration prim opens its menu on touch. The companion avoids opening a second touch dialog alongside the controller.
3. For the first farm, keep the automatically populated Farm UUID. For additional controllers, **Join farm** and paste that farm's UUID before registering.
4. **Register** opens `/register` with owner, farm and current root UUIDs already filled in. Enter a display name. Sign in with the existing administrator account; successful login returns to the registration page. No repeated administrator bootstrap or administrator secret entry is needed for approval through this session.
5. Submit registration. The administrator-approved farm owner cannot be changed by enrolling another controller. Duplicate root UUIDs are rejected atomically.
6. Store the returned per-controller credential privately. The optional CloudSync script uses this credential; its state now includes the actual owner and root UUID. Changing those declared identities is rejected with 403. UUIDs alone never grant access.

This is administrator-approved registration, not public automatic avatar verification. The web form is prefilled from SL, but the server does not claim simulator attestation of ownership. Approval and private controller credentials remain necessary.

## Existing farm migration

Migration `0004_sl_uuid_identity.sql` adds UUID identity columns and indexes. It does not drop or rename existing records, reset credentials, change passwords, or touch inventory. Existing string IDs stay internal so all foreign-key relationships and transaction history remain intact.

Update CloudSync scripts to the new version before binding a legacy controller; older companions do not report owner_uuid and would be rejected after mapping. Then apply migration 0004 through the existing D1 migration process and deploy this branch's Worker together with identity.js and registration.js. The current live Worker/database are not changed merely by committing this code.

An administrator explicitly calls `POST /v1/admin/bind-sl-identity` with the old internal farm ID, actual Farm UUID, actual owner UUID and each old object ID's actual root UUID. It accepts the existing signed-in administrator session or operator credential. The entire mapping is one D1 transaction. Duplicate UUIDs, unknown objects or attempts to replace a bound owner are rejected. Do not invent UUIDs or clear tables to resolve a collision.

Example request shape (replace placeholders with actual values):

```json
{
  "legacy_farm_id": "existing-internal-id",
  "farm_id": "ACTUAL-FARM-UUID",
  "owner_uuid": "ACTUAL-OWNER-AVATAR-UUID",
  "objects": [{"legacy_object_id": "old-controller-id", "object_id": "ACTUAL-ROOT-UUID"}]
}
```

Legacy inventory, account password hashes, sessions and object credentials are retained. Existing farm users sign in with **owner UUID + Farm UUID + their existing password** after mapping. Multiple farms can use the same owner UUID; Farm UUID selects the account. Administrator login remains the existing administrator account.

Unmapped legacy farms are retained and marked for mapping; the public dashboard does not present their old aliases as SL UUIDs. New registration, credential rotation, farm login and dashboard farm selection use canonical UUIDs. No production deployment or in-world acceptance is claimed until explicitly tested.
