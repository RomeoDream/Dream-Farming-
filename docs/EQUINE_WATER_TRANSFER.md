# Equine Stable → Herd water transfer pilot

Status: **code committed, compilation and Second Life testing pending**.

The experimental Stable controller can now send a fixed 10-unit `WATER` load to the linked Herd using the farm's existing `NET` transfer protocol. This is **not** the complete hay/feed or compost integration.

## How the transfer works
1. Owner links a same-owner Herd root and keeps the objects within 8 m.
2. Stable owner selects **Send water**; the stable records a durable 10-unit reservation, sequence number and persistent stream ID in linkset data.
3. On its timer the Stable sends `LOAD` to the linked Herd. A missing reply triggers retries at intervals of at least 10 seconds.
4. The Herd's existing receiver validates owner, distance, target, stream, sequence, material and quantity, credits WATER once and persists a receipt before sending `ACK`.
5. Stable checks that the ACK came from its linked Herd and matches stream, sequence, quantity, material and target, then debits 10 local water units and clears its reservation.

## Safety boundaries
- Do not change the linked Herd while a transfer is pending.
- Do not copy, sell, or delete a Stable with a pending transfer; its local stock is not a server-authoritative commodity.
- Herd receiver retains only a bounded number of sender streams; repeated resets/replacements may require reconciliation.
- Existing Stable care monitoring remains observational. It must not independently charge animals' feed/water or mint manure.
- No transfer of hay, bedding or manure is implemented in this pilot.

## In-world verification
- Successful transfer: Stable -10 WATER, Herd +10 WATER, pending cleared.
- Lost ACK: retry returns same receipt and no second Herd credit.
- Herd full/paused/faulted: Stable reservation remains pending and no debit occurs.
- Wrong owner, region or distance >8 m: no delivery.
- Reset Stable while pending: same stream and sequence are retried.
- Attempt to change Herd while pending: rejected.
- Repeated ACK: no second Stable debit.
- Missing Herd: pending remains visible, no silent refund.
- LSL compile as Mono and record memory consumption on both scripts.

No acceptance outcomes are claimed until these tests are actually run.
