# Architecture and persistence contract

## Ownership boundaries

Each controller owns one local state record in its own linkset. No central farm server exists. Menus are owner-only by default; opt-in active-group workers have a restricted care/work-order whitelist. Object-owner/range checks guard local material delivery. Optional bank/fuel/power adapters retain their own authority; local stock never implies payment. Negative channels are protocol addresses, not secrets.

| Controller | Linkset Data key | Fixed array length | Output block |
| --- | --- | --- | --- |
| Field (schema 2) | `dreamfarm:field:v1` | 55 | 50–54 |
| Livestock | `dreamfarm:livestock:v1` | 32 | 27–31 |
| Compost | `dreamfarm:compost:v1` | 29 | 24–28 |
| Garden applicator | `dreamfarm:applicator:v1` | 20 | 15–19 (destination setting; no farm output) |
| Garden current producer bridge | `dreamfarm:gardenlink:v1` | 18 | 13–17 (unused farm output) |
| Storage | `dreamfarm:storage:v1` | 22 | 17–21 |
| Processor | `dreamfarm:processor:v1` | 25 | 20–24 |
| Herd | `dreamfarm:herd:v1` | 28 | 23–27 |
| Machine | `dreamfarm:machine:v1` | 24 | 19–23 (field destination; no material output) |
| Irrigation | `dreamfarm:irrigation:v1` | 23 | 18–22 |
| Board | `dreamfarm:board:v1` | 17 | 12–16 (unused output) |
| Office | `dreamfarm:office:v1` | 22 | 17–21 (unused output) |

Array indices 0–7 are common: schema number, owner UUID, controller kind, last UTC second, paused flag, speed (1 or 60), simulated days, and frozen excess offline seconds. Module-specific indices are documented in each source. Field migrates schema 1 by inserting seven fields before its old outbox, then atomically saves schema 2. Existing outbox/receipt values remain intact; failed migration saves leave the original bytes and lock operation. The key name remains `:v1` to locate existing data.

Each five-item output block contains destination UUID, sequence counter, reserved quantity, material kind and persistent sender-stream UUID. Up to eight receipt records follow the fixed array. Each receipt is four items: stream UUID, highest accepted sequence, quantity, material kind. Receipts are never evicted.

One `llLinksetDataWrite` stores the entire array. Harvest removal and local credits share a save. A transfer debit and outgoing reservation share a save. Receiver credit and receipt share a save. Success follows a durable save. A failed write restores the preceding in-memory array, locks actions and leaves the prior saved record intact. Invalid schema/types/ranges or a changed owner lock without overwriting.

This protects ordinary repeated clicks, message retries and script resets. It does not provide transactions against simulator rollback, copied objects, malicious owners, competing scripts in the same linkset, root relinking, or external database failure. Same-owner scripts and the linkset are trusted.

## Farm transfer protocol

Channel `-163847025`, targeted `llRegionSayTo`, JSON object under 1024 bytes:

```json
{"v":1,"op":"LOAD","target":"receiver-root-uuid","stream":"persistent-sender-uuid","seq":1,"qty":10,"kind":"MANURE"}
```

Kinds use semantic names in `src/catalog.lslinc`. Each receiver has an explicit material/capacity policy. Storage/Processor accept catalog materials; fields accept seed, water, fertilizer, compost, diesel and energy; herds accept feed, grass, water, bedding and medicine; compost accepts manure, browns and digestate. Current Garden bridge accepts only fresh manure. Legacy Garden applicators accept only mature compost. Quantities are positive whole units up to 1000. Fractional production stays in local stock until enough exists for a whole-unit load.

The receiver validates version, target, UUID, numeric fields, range, actual sender owner and object identity. It rejects avatars. It accepts an unseen stream if fewer than eight streams exist, or a greater sequence on a known stream. It saves material plus the high-water receipt, then replies with `op:ACK` and the same stream/sequence/quantity/kind, targeting the sender.

A matching duplicate returns ACK without crediting again. A replay of an older sequence also gets an ACK without a credit. Equal sequence with changed quantity/kind is rejected. Out-of-order future delivery is not supported as a sender never has two outstanding loads.

Sender ACK acceptance requires the exact bound destination, stream, current sequence, material and reserved quantity. After a saved ACK, reserved quantity becomes zero. Retries use the same reservation about every 15 seconds. No automatic timeout refund exists. Receipt capacity, unsupported material, pause, distance, full storage or receiver lock can hold a delivery pending. The current alpha exposes pending quantities but has no remote rejection-status API.

Destination change is blocked while a farm load is pending. A destroyed/re-rezzed destination with a changed UUID requires manual audited recovery; retries cannot locate it automatically. Farm transfers work only in the same region and within 8 m. Inventory permissions and anti-copy enforcement are not part of this protocol.

## Time

Simulation uses elapsed integer Unix time, not a count of timer callbacks. Fixed slices and bounded per-event work make normal catch-up deterministic. Unprocessed time remains as backlog. Events cannot apply care retroactively while a backlog remains. Offline time exceeding 24 real hours is frozen explicitly. Pause discards paused time. Speed changes discard at most one partial slice after settling complete slices; this is a documented sandbox tradeoff.

The game-day clock is local to each object. The seasonal model is deterministic and stylized. There is no external weather feed, geographic calendar, precision agronomic calibration or globally synchronized farm clock.

## Rendering and future integration

Root-local message `48100` carries compact display JSON; `48101` requests a new snapshot. The included visual script accepts only its own prim's field messages, changes only specifically named children, and never edits controller state. Actual animations, crop-specific meshes, PBR materials and sounds remain asset work.

Future adapters should preserve semantic material names, amounts, source identities, immutable transaction IDs and confirmation-before-finalization behavior. Server authority should own a durable deduplication ledger and stock, rather than trusting copied LSL inventories. No real-money or banking authority may be inferred from local roleplay stock.

## Expansion transactions

- Processor input debit, output reservation and batch-start flag share one save. Output and completion flag share another. Capacity includes pending outbound loads and reserved output; biogas/digestate reserve both outputs.
- Herd animal arrays, resource use, birth records and parent changes are saved together. UUIDs identify individuals; the eight-record bound controls state size. Removing dead records does not retain a full archive.
- Field machine coverage stores two 32-bit masks and an immutable active source/job/tool/crop tuple. Only actual-position cells count. The 64th cell and operation result save together; a blocked sow/harvest rolls back that final cell. Coverage is not a continuously swept implement footprint.
- Machine saves fuel debit and a two-second lease before responding to the driver. Duplicate current request IDs do not debit twice. The driver accepts only its outstanding root-local request, expires motion locally and releases controls on unseating.
- Pump reservations debit drawn water, leakage and local energy before dispatch. Lost ACKs do not trigger another draw for the same pending load.
- Office stores one immutable invoice per job before any issue request; only correlated full payment increments the historical total. Completed work orders are manual reports, not authenticated field telemetry.
- Board readings are ephemeral, explicitly aged and tied to current query nonce plus registered source. Only node registration is persisted.

The local inventory schema is not a future server API. A server migration must establish authoritative IDs and reconciliation rules without importing copied inventories as trustworthy balances. The implemented integration contracts are documented in [INTEGRATIONS.md](INTEGRATIONS.md).

## References

- [Linden Lab: Linkset Data persistence and return codes](https://create.secondlife.com/script/lsl-reference/functions/lllinksetdatawrite/)
- [Linden Lab: targeted region chat, size limits and ordering caveats](https://create.secondlife.com/script/lsl-reference/functions/llregionsayto/)
- [Linden Lab: llGetUnixTime](https://wiki.secondlife.com/wiki/LlGetUnixTime)
- [Lummao source](https://github.com/SaladDais/Lummao)

The tests run the actual LSL source through Lummao 0.5.2. Mocked simulator services cannot establish Mono heap use, viewer rendering, real throttles, attachment behavior or simulator scheduling.
