# Architecture and persistence contract

## Ownership boundaries

Each controller owns one local state record in its own linkset. No central farm server exists yet. Farm-to-farm material delivery is the only cross-object economic change. Owner-only dialogs and object-owner/range checks are enforced. Negative channels are protocol addresses, not secrets.

| Controller | Linkset Data key | Fixed array length | Output block |
| --- | --- | --- | --- |
| Field | `dreamfarm:field:v1` | 48 | 43–47 |
| Livestock | `dreamfarm:livestock:v1` | 32 | 27–31 |
| Compost | `dreamfarm:compost:v1` | 29 | 24–28 |
| Garden applicator | `dreamfarm:applicator:v1` | 20 | 15–19 (destination setting; no farm output) |

Array indices 0–7 are common: schema 1, owner UUID, controller kind, last UTC second, paused flag, speed (1 or 60), simulated days, and frozen excess offline seconds. Module-specific indices are documented above the code in each `src/DreamFarm_*.lsl`.

Each five-item output block contains destination UUID, sequence counter, reserved quantity, material kind and persistent sender-stream UUID. Up to eight receipt records follow the fixed array. Each receipt is four items: stream UUID, highest accepted sequence, quantity, material kind. Receipts are never evicted.

One `llLinksetDataWrite` stores the entire array. Harvest removal and local credits share a save. A transfer debit and outgoing reservation share a save. Receiver credit and receipt share a save. Success follows a durable save. A failed write restores the preceding in-memory array, locks actions and leaves the prior saved record intact. Invalid schema/types/ranges or a changed owner lock without overwriting.

This protects ordinary repeated clicks, message retries and script resets. It does not provide transactions against simulator rollback, copied objects, malicious owners, competing scripts in the same linkset, root relinking, or external database failure. Same-owner scripts and the linkset are trusted.

## Farm transfer protocol

Channel `-163847025`, targeted `llRegionSayTo`, JSON object under 1024 bytes:

```json
{"v":1,"op":"LOAD","target":"receiver-root-uuid","stream":"persistent-sender-uuid","seq":1,"qty":10,"kind":"MANURE"}
```

Kinds are `MANURE`, `BROWNS`, `COMPOST`. Only compost receives manure/browns; fields and applicators receive mature compost. Quantities are whole positive units up to 1000. The current controls dispatch 10 kg manure/residue, 2 kg bedding and 2 kg compost.

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

## References

- [Linden Lab: Linkset Data persistence and return codes](https://create.secondlife.com/script/lsl-reference/functions/lllinksetdatawrite/)
- [Linden Lab: targeted region chat, size limits and ordering caveats](https://create.secondlife.com/script/lsl-reference/functions/llregionsayto/)
- [Linden Lab: llGetUnixTime](https://wiki.secondlife.com/wiki/LlGetUnixTime)
- [Lummao source](https://github.com/SaladDais/Lummao)

The tests run the actual LSL source through Lummao 0.5.2. Mocked simulator services cannot establish Mono heap use, viewer rendering, real throttles, attachment behavior or simulator scheduling.
