# Dream Farming Cloudflare test candidate

The existing deployed farm already has D1, accounts and an administrator. **Do not recreate the database or bootstrap the administrator again.** Keep the current secrets and approved dashboard asset.

The Worker implements per-object bearer enrollment, revision-checked state synchronization, farm accounts and administrator pages. This candidate fixes rotated credentials and invalid request bodies, and excludes telemetry older than five minutes from current totals. Existing migrations and data are retained; no schema change is required for this batch. Deploy through the existing Cloudflare workflow only when testing these Worker changes; this repository commit does not itself deploy the live Worker.

## Optional Second Life companion

Use generated `lsl/DreamFarm_CloudSync.lsl` beside one Herd, Field or Machine root controller. It is disabled by default. An administrator provisions a dedicated object credential with the existing `POST /v1/admin/enroll` endpoint, sending farm_id, farm_name and object_id under the existing x-admin-token. Never put the administrator token or password in LSL. Configure only the returned per-object credential and HTTPS API_URL privately in the companion.

A fresh object credential/identity is required for copied or changed-owner roots. The companion publishes actual controller measurements, never stock authority or money. It GETs the current server revision, POSTs observed telemetry, backs off on outages and re-reads revision after conflicts. Local farming continues independently.

## Automated checks

`node --test cloudflare/tests/*.test.mjs` runs actual Worker code against all existing migrations in Node's built-in SQLite engine. It checks enrollment/authentication, isolation, revision conflicts, rotation/revocation, malformed/oversized requests, one-time bootstrap, login/logout, real farm-filtered totals and staleness. Node 24 is used in CI. These tests do not replace live D1/Worker/SL HTTP verification.

The Worker is a telemetry/state service. It does not turn copied sandbox stock into authoritative cross-owner inventory, bank payments or cargo transactions.
