# Cloudflare backend architecture (design milestone)

Status: **design only; not deployed or integrated**. Existing 0.3.0 field operations alpha remains usable without a backend.

## Components

- Cloudflare Worker: HTTPS API gateway for Second Life `llHTTPRequest` clients; validate every request, limit payload sizes, rate-limit and return compact JSON.
- D1: durable farms, objects, inventories, fields, animals, transfers, work orders and audit events. Each row carries `farm_id`, `revision`, `updated_at`.
- Durable Objects (optional later): serialize high-contention per-farm operations. Start with D1 transactions and conditional revision updates.
- Queues (optional): deferred cross-system notifications and analytics; never make queue delivery the source of inventory truth.

## Security and tenancy

A farm belongs to an account, not merely an SL group name. Register each in-world object with a server-issued credential, rotate and revoke credentials, and associate it with exactly one farm. Treat SL owner UUID as an asserted identity unless separately verified; do not trust client-supplied farm IDs or balances. Store credential hashes, not raw secrets. No secrets in LSL public scripts or git. Enforce authorization on every endpoint. Banking and TXAGO use separate scoped service credentials and explicit opt-in.

## API draft (versioned)

- `POST /v1/objects/register` — authenticated enrollment, returns object identity and credential through a controlled provisioning workflow.
- `POST /v1/state/sync` — object ID, revision, snapshot and idempotency key; conditional update; reply with new revision or conflict.
- `POST /v1/transfers/reserve` — create expiring stock reservation, durable transaction ID and audit record.
- `POST /v1/transfers/commit` — exactly-once server-side accounting per transaction ID; retries return same receipt.
- `GET /v1/objects/{id}/state` — authorized snapshot and revision.
- `GET /v1/farms/{id}/summary` — scoped overview for farm owner/authorized managers.
- `GET /health` — no sensitive data.

## Sync policy

Existing local LSL saves remain authoritative for offline single-object gameplay until a farm opts into server mode. In server mode, D1 becomes authoritative for shared inventory and cross-region transfers; clients cache read-only projections and cannot mint stock offline. Use idempotency keys for retries, bounded HTTP response bodies, exponential backoff, and explicit conflict handling. Never delete local state on a timeout. Record schema versions and support migration from local saves only after operator confirmation.

## Rollout gates

1. Create Worker + D1 schema, migrations, test harness and local dev configuration.
2. Add authentication and scoped registration; test spoofing, replay, credential rotation and cross-farm denial.
3. Implement conditional state sync and transactional inventory reservations with duplicate-request tests.
4. Add an opt-in LSL adapter with timeout/backoff handling, HTTP quota awareness and small JSON payloads.
5. Stage with two farms, multiple objects, simulated HTTP failures and cross-region travel; reconcile inventory totals.
6. Deploy only after credentials are provisioned and real in-world acceptance tests pass.

## Boundaries

Cloudflare cannot remove Second Life parcel permissions, physics limitations, script memory limits or HTTP throttling. No live backend, verified authentication, or cross-region economy is claimed by this document.
