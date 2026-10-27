# Equine Stable → Herd feed and water transfers

Status: implemented and exercised with actual LSL through Lummao 0.5.2; Second Life Mono and in-world qualification remain pending.

The experimental Stable sends fixed 10-unit WATER or FEED loads using the existing farm NET protocol. Hay maps to FEED. Herd remains the only authority for welfare consumption and manure production.

## Durable ordering

1. Select a same-owner Herd within 8 m.
2. Reserve the selected stock. A single v3 linkset-data record commits stock, target, stream, sequence, material, quantity and retry diagnostics together before any LOAD is sent.
3. The 60-second Stable timer retries the same delivery. Failed persistence locks the Stable and prevents sends.
4. Herd credits stock and commits its existing receipt atomically before ACK. Duplicate LOAD returns its saved receipt without a second credit.
5. Stable validates the complete ACK, then atomically debits stock and clears the reservation. A failed ACK save restores the prior durable reservation and locks actions. Repair storage and reset to reconcile against the Herd receipt.

## Migration and identity

Legacy v2 keys are retained, read once when no v3 record exists, and migrated to one validated snapshot. Subsequent boots read only v3. Never remove v3 to force a downgrade: legacy keys become historical after migration.

V3 records bind to both owner and object UUID. Copies, owner changes and re-rez with a different object UUID lock existing records without overwriting them. An uncertain pending delivery requires reconciliation, never an automatic refund. Use a fresh empty object for a new Stable. Legacy objects copied before migration cannot be reliably distinguished; supplies remain sandbox roleplay stock, not server-authoritative tradable inventory. Other farm modules retain their existing local-copy limitations.

## Verified locally

Runtime tests execute Stable and Herd LSL for feed/water delivery, dropped ACK with both scripts reset, duplicate ACK, reservation/retry/ACK save failures, receiver save failure, malformed records, migration of pending legacy stock, copied/other-owner records, out-of-range retries, destination locking, and verified equine assignments. Care monitoring does not independently consume supplies or generate manure.

Horse and donkey birth tests verify one pedigreed foal per pregnancy and no repeated birth after reset. Existing Herd-to-Compost tests cover finite manure delivery; the Stable does not collect or export Herd manure yet.

## Remaining gates

Compile in Second Life Mono; record free memory at eight animals and eight receipt streams; exercise actual simulator resets, re-rez, region restarts, message loss and dialogs. Validate meshes and animal motion separately. Bedding transfer, Stable manure collection, full welfare telemetry and authoritative inventory remain unfinished. Do not copy, sell or delete objects with unresolved transfers.
