# Existing Farming deployment target

The existing Cloudflare build check identifies the Worker as `dream-farming`. Wrangler now uses that same name; the old `dream-farming-api` name conflicted with the connected Worker. Keep the existing `dream-farming` D1 binding and database ID. `keep_vars = true` preserves dashboard-managed runtime variables. No secrets, database IDs, administrator records or inventory are changed.

For the UUID registration candidate, select branch `feature/sl-uuid-registration` and root directory `cloudflare` in this existing Worker's build settings. Deploy `npx wrangler deploy`. Migration 0004 must be applied once through the existing D1 migrations procedure before UUID registration is accepted; do not replay all historical SQL manually. Review the existing migration history and retain a recovery bookmark before remote schema changes. Do not recreate D1 or bootstrap the administrator again.

A successful build is not owner registration acceptance. Verify `/health`, `/register`, existing admin login, controller owner binding, copied-object rejection and revision recovery in Firestorm. The migration and registration deployment are not verified merely by this source change.
