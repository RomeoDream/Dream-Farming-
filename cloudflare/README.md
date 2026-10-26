# Dream Farming — Cloudflare Worker (initial implementation)

This milestone implements D1 schema, operator-only enrollment, per-object bearer authentication, optimistic revision-based state sync, and state retrieval. It does **not** implement transfers, banking, or in-world LSL networking yet. Not deployed or tested in Cloudflare.

## Setup (Cloudflare dashboard or Wrangler)
1. Create a D1 database named `dream-farming` in Cloudflare and replace `REPLACE_WITH_D1_DATABASE_ID` in `wrangler.toml`.
2. Run D1 migration `migrations/0001_initial.sql` using the Cloudflare dashboard SQL console, or Wrangler migration commands.
3. Set `ADMIN_TOKEN` as a Worker secret (not a plaintext variable or committed file).
4. Deploy the Worker and confirm `GET /health` returns `ok: true`.
5. Provision objects only from an administrator-controlled HTTPS client using `POST /v1/admin/enroll` with `x-admin-token`, JSON `{"farm_id":"farm1","farm_name":"Farm One","object_id":"object1"}`. Keep the returned credential private.
6. Objects authenticate with `Authorization: Bearer <credential>`. POST `/v1/state/sync` JSON `{"revision":0,"state":{"crop":"corn"}}`; GET `/v1/state` retrieves saved state.

## Limitations and security
Never place ADMIN_TOKEN in LSL scripts or public GitHub files. Object tokens are sensitive and can be exposed in transferable/modifiable objects; this is a first milestone, not a production-grade public economy. Enrollment is operator-controlled; identity attestation, rotation, abuse throttling, transfers and multi-object reconciliation remain pending. D1 writes are guarded by revisions to prevent lost updates. Use a unique object ID per object, not a shared credential. No live deployment is claimed.
