# Optional integrations — inspected interfaces

The farming core needs no external service. Each optional integration must be configured against its existing system. Nothing here deploys a server, creates credentials, approves a bank business or starts accepting payments. Same-root scripts are trusted; linked-message codes are not authentication against malicious scripts inside that root.

## Dream-Garden

The current path sends finite manure to Garden's producer API and uses Garden's own compost/bin/fertilizer workflow. See [MANURE_AND_GARDEN.md](MANURE_AND_GARDEN.md). Current Garden v0.4 and the older v0.3 applicator are deliberately separate compatibility targets.

## TXAGO engine authority

Inspected [TXAGO_Engine_Controller.lsl](https://github.com/RomeoDream/TXAGO-2.0/blob/feature/hq-fuel-readonly-api/lsl/TXAGO_Engine_Controller.lsl), blob `dd7ab1a2bea492cc58ad78a83563bcbdb52ee2c6`, on `feature/hq-fuel-readonly-api`. Follow its [operations guide](https://github.com/RomeoDream/TXAGO-2.0/blob/feature/hq-fuel-readonly-api/docs/operations-rc6.md) for registration and server configuration.

Place the configured TXAGO engine controller in the same tractor root. Set farming Machine `USE_TXAGO=TRUE` and its exact registered `ENGINE_ID`. Machine sends linked **-46443536** commands:

```json
{"kind":"COMMAND","engine_id":"registered-engine-uuid","state":"RUNNING","load_permille":1000}
```

States are OFF, IDLE and RUNNING. Machine grants driving leases only after matching same-root STATUS for the configured engine, requested state and `allow_run:1`. STOP, denial, stale status or saved-state failure stops authorization. Local diesel is not debited in TXAGO mode; the existing engine controller/server remains fuel authority. A fresh lease also requires the farming engine switch and a healthy machine. Script reset requires a new manual engine start.

Local tests verify command shapes, matching IDs, root filtering, authorization gating and STOP behavior. They do not execute the TXAGO server or prove real HTTP/region timing. Failed/stale communication must be tested in-world before use.

## Dream Power Company

Inspected [DPC_Appliance.lsl](https://github.com/RomeoDream/Dream-Power-Company/blob/feature/lsl-integrated-utility/lsl/DPC_Appliance.lsl), blob `87984de9efb7dc4bf97fb3c0043f6e2a85b15db4`, and [integration contract](https://github.com/RomeoDream/Dream-Power-Company/blob/feature/lsl-integrated-utility/docs/INTEGRATIONS.md) on `feature/lsl-integrated-utility`.

Put a configured DPC appliance in the same Field, Processor, Storage or Irrigation root, set appliance `EXTERNAL_DEMAND=1`, and set the farm controller's `USE_DPC=TRUE`. Follow DPC's panel/circuit/cord setup. The farming controller sends **7212** demand JSON `{op:"DEMAND",watts:N}` every 15 seconds while serviced. Paused objects request zero demand.

Farming accepts same-root **7210**, version 2, `op:"APPLIANCE"`. Supply must have `on:1`, `powered:1`, and `enabled:1`, with a heartbeat no older than 45 seconds. Existing elapsed slices are settled before accepting a new observation, so a fresh heartbeat after reset does not power historical catch-up.

| Load | Demand |
| --- | --- |
| Greenhouse climate | 2,000 W when enabled |
| Active non-silage processor | 4,000 W |
| Cold storage | 2,000 W |
| Enabled pump with open valve | 500 W |

DPC mode gates operation on appliance availability and disables local-energy fallback. It does not credit the DPC grid from local batteries/biogas. Simulation uses coarse slices, so energy effects are approximations rather than a precise integration of the DPC meter. Tests cover fresh supply, root rejection, outages and absence of local fallback; real circuits, bills, physical cords and simultaneous dialogs still need live testing.

## Dream Banking service invoices

Inspected [billing contract](https://github.com/RomeoDream/Dream-Banking/blob/main/docs/BILLING_API.md), blob `17e8db9f5f2da4b4e47e1f77c12e07365a308c36`, and [Dream_Bill_Terminal.lsl](https://github.com/RomeoDream/Dream-Banking/blob/main/lsl/Dream_Bill_Terminal.lsl), blob `5a1f4e0ab43e096cee3a8e79a7981d1f05608d71`.

1. Use a fresh Office configured with `USE_BANK=TRUE` and the existing business UUID in `BUSINESS_ID`.
2. Install the bank terminal in that same root, set its `BANK_ROOT` and matching `BUSINESS_ID`, and have the bank owner approve this root as BILL. The adapter owner must own the business.
3. Complete a work order. **Invoice details** accepts `payer-avatar-UUID|integer-cents|due-days`; 2500 means fictional RP$25.00. Review the displayed draft, then choose **Issue invoice**.
4. The office saves an immutable bill UUID, customer, amount, term and description before issuing linked **42001**. It uses **42003** to query and reuses that ID after a reset or lost reply. The customer pays through the bank's normal bill interface; issuance alone does not debit them.
5. Root-local **42002** must match version, bill, business, payer, exact amount and nondecreasing paid amount. Only a full `PAID` confirmation adds that bill once to the office's historical paid-services total. OPEN/PARTIAL/unknown status does not count as full payment. Older replies cannot undo a final state.

One bill can belong to each retained work order. Existing bills are never replaced to resolve an unknown outcome. The office does not dispense goods, authorize commodity exports, compute wages or create spendable balances. The bank remains authoritative. Do not change business/root/owner bindings while bills need reconciliation.

Tests execute the actual pinned bank terminal fixture: issue, reject forged radio replies, accept a correlated bank response, replay after reset, then apply payment once at the office. They simulate the bank response, not the bank's entire ledger/payment system. The terminal and Office can both display owner dialogs; choose the Farm Office dialog for work orders. In-world payment and concurrency tests remain required.

## Protocol addresses

| Purpose | Address |
| --- | --- |
| Farm material LOAD/ACK | Region channel `-163847025` |
| Machine WORK/WORK_STATUS | Region channel `-163847026` |
| Board QUERY/STATUS | Region channel `-163847029` |
| Farm display/status request | Linked `48100` / `48101` |
| Driver request/lease/stop | Root-linked `48200` / `48201` / `48202` |
| Restricted physical cab commands | Root-linked `48300` |
| Current Garden producer/ACK | Root-linked `47130` / `47131` |
| Legacy Garden tool | Region channel `-163847020` |
| TXAGO engine | Linked `-46443536` |
| DPC appliance/demand | Root-linked `7210` / `7212` |
| Bank issue/status/query | Root-linked `42001` / `42002` / `42003` |
