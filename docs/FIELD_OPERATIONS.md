# Field operations — 0.3.0 alpha

This release adds three scripts: `DreamFarm_ManureStore`, `DreamFarm_Pasture`, and the `DreamFarm_Cab` companion. Machine and Field receive atomic state migrations. All quantities, weather and nutrient effects remain configurable roleplay approximations.

## Manure storage and separation

Place `DreamFarm_ManureStore.lsl` in a fresh root. Send MANURE, BROWNS, SLURRY or DIGESTATE from the herd, processor or storage. Water, local energy and parts are also accepted. Default capacity is 2,000 normalized units, including outgoing reservations. The initial service supplies are 20 energy and five parts; waste stock starts empty.

- **Select material → Send 10/Send 100** delivers finite stock to a compatible receiver within 8 m. Examples: raw manure/browns to compost, slurry to a digester, manure/slurry/digestate loading at the Machine. This store does not accept mature COMPOST; use ordinary Storage or the Compost pile to load that material.
- **Cover** toggles rain exclusion. An uncovered store catches modeled rain; excess beyond free capacity is counted as spilled. Incoming deliveries that would exceed capacity are held at their source, not dumped into the store.
- Liner wear rises while waste is held. Above 70% wear, stored liquid slowly leaks. Leaks subtract actual water/slurry and increment the spill counter. Outgoing reserved loads do not leak.
- **Repair liner** consumes one part, stops that wear-related loss and preserves the historical spill counter. It never restores lost material.
- **Agitate** consumes one local energy unit. **Separate 10** needs recent agitation and another energy unit, converting ten slurry into three raw solids (`MANURE`) and seven process-water (`WATER`) units. New slurry invalidates the previous agitation. Material age is a weighted storage-age display and never automatically turns manure into compost.

The separator uses simplified material categories. Process water is not certified drinking water; this release has no separate effluent chemistry or water-quality ledger. It does not model biological sanitation, realistic gas hazards or real fertilizer analyses.

## Loading and operating the spreader

The Machine now has a 500-unit mixed spreading hopper. Load it using ordinary same-owner material transfers from a source within 8 m. It accepts MANURE, SLURRY, COMPOST and DIGESTATE. Fuel/parts remain separate from hopper capacity. There is no fabricated sandbox manure button.

1. Set Machine **Settings → Destination** to the Field root.
2. **Implement → Spread** selects spreading and creates a raised job.
3. **Spreader setup** selects material and dose: one, two or four units per cell. Changing either starts a new raised job.
4. **Engine** starts the engine request. **Cab controls → PTO** engages PTO. Hitch and hydraulic circuit must be enabled. **Lower or raise** lowers the implement and consumes a small amount of hydraulic fluid.
5. Drive across the field. The working motor target is 2 m/s. New doses require actual speed between 0.2 and 2.5 m/s, the owner within 40 m of the field, and the machine inside the field rectangle within 4 m vertically.
6. Each previously untreated cell in this machine job reserves a dose from the selected stock. Field and Machine share the configured `FIELD_WIDTH`/`FIELD_DEPTH`, default 20×20 m, divided into 64 cells. Both use the field root's actual position and rotation. Change dimensions consistently on both scripts.
7. A confirmed cell sets a persistent machine coverage bit. Repeated passes in that job do not spend another dose. At 64 cells the implement raises. **New job** deliberately permits another pass; accumulated applications may harm the crop.

The special spreading load contains an immutable `SPREAD|material|cell` kind and uses the existing sequence/receipt protocol. Its travel allowance is 40 m, while ordinary stock loading remains 8 m. A fresh dose is accepted only at its bound actual cell. The field saves the nutrient effect, local application total and receipt together; the machine saves the stock debit/reservation before sending.

If the dose reached the field but the ACK was lost, retrying confirms the original cell without applying again, even after moving within range. If the original dose never arrived, return to its bound cell, moving at the permitted speed, so it can finish. Material, dose, implement and job changes are blocked while a dose is pending. No automatic refund or discard creates replacement stock.

**Field → Utilities → Field setup → Spreading report** shows the decaying recent application load, cells above the modeled four-unit threshold and runoff index. Different materials add different averaged N/P/K values. Wet soil and excessive local application increase runoff; overapplication or high nitrogen damages a planted crop. Recent cell loading decays by 5% per farm day. This is an abstract nutrient-pressure model, not a real application-rate recommendation.

Raw MANURE/SLURRY is still rejected by the field's ordinary storage inlet. Only the deliberate moving-spreader application can apply it directly. Mature compost can still enter the original field compost stock and be applied through its care menu. Current Garden integration continues through its native manure/compost path.

## Implement and service controls

**Cab controls** offers PTO, Hydraulics, Hitch and Inspect. Harvest and Spread need PTO; all fieldwork needs a lowered implement, a latched hitch, an open hydraulic circuit and fluid. Closing a circuit or disengaging PTO prevents new qualifying work. Already saved transfers remain pending until acknowledged.

Hitch changes require a stopped engine, raised implement, disengaged PTO and no pending load. The hitch is a control interlock; it does not physically link, tow or move an attachment. Physical hitching and animated equipment are still asset/in-world work.

The driver receives speed caps with each saved lease: 2 m/s while plowing/sowing/harvesting/spreading, 3 m/s while weeding, otherwise 4 m/s travel. Reverse is capped at 2 m/s. These are motor targets, not guarantees against momentum/slopes. PTO under working load imposes a minimum modeled engine load, including for optional TXAGO commands.

Machine tracks authorized engine seconds as hours, filter wear and hydraulic fluid. A 95%-worn filter blocks further driving leases. **Service** requires engine off and one service-kit parts unit; it restores machinery/filter/fluid condition but retains total hours. Reset stops the engine and PTO; restart both manually where required. Saved hopper quantities, coverage and pending doses survive.

## Physical cab controls and gauges

Put `DreamFarm_Cab.lsl` beside Machine and TractorDriver in the same root. Create child prims or mesh components with these exact names. Root touch opens the normal Machine menu; child controls send restricted owner commands without opening another menu.

| Child name | Function |
| --- | --- |
| `DF:Control:Engine` | Engine switch |
| `DF:Control:PTO` | PTO switch |
| `DF:Control:Hydraulics` | Hydraulic circuit switch |
| `DF:Control:Hitch` | Hitch latch interlock |
| `DF:Control:Lift` | Raise/lower control |
| `DF:Light:Engine`, `DF:Light:PTO` | Requested switch states |
| `DF:Light:Hitch`, `DF:Light:Hydraulics` | Interlock states |
| `DF:Light:Pending` | A reserved delivery is outstanding |
| `DF:Light:ExternalFuel` | TXAGO is fuel authority |
| `DF:Light:Fault` | Reported fault or no fresh snapshot for over 30 seconds |
| `DF:Gauge:Fuel` | Local diesel needle, 0–250 L |
| `DF:Gauge:Wear` | Machine wear needle, 0–100% |

Needle sweep defaults to 180 degrees about local Z. Set `FUEL_ZERO`, `WEAR_ZERO` and `NEEDLE_SWEEP` for the actual mesh. Only named children are edited. Stale data extinguishes state lights and illuminates the fault indicator; needles retain their last position. TXAGO mode does not move the local-fuel needle from an invented remote balance. An engine request lamp is not proof that an external engine has authorized motion.

## Pasture and rotational grazing

Place `DreamFarm_Pasture.lsl` in a fresh root. It begins with 600 standing grass units, maximum 1,000, and finite starter water/seed. Regrowth depends on remaining cover, health, local seasonal light/temperature, moisture, fertility and compaction. Drought, waterlogging and frost can destroy grass; cut grass spoils.

- **Mow 50** removes fifty standing units into local cut-grass stock only if at least 100 standing units remain.
- **Low cut → Confirm low cut** permits a deeper cut, explicitly damaging thin cover. Removing all cover prevents ordinary regrowth until reseeded.
- **Send cut grass** reserves twenty units for a compatible nearby herd, storage or processor. A Baler can turn the delivered grass into hay.
- **Grazing gate** enables an automatic twenty-unit delivery every eligible 15-second service interval, retaining at least 100 standing units. Set its destination to a nearby Herd and enable that herd's **Grazing** option. Close the gate and change destination to rotate pens.
- Automatic delivery is bounded by pasture stock and pending receipts; it is not driven by current animal hunger or physical animal positions. Delivered grass can accumulate in the herd's finite inventory. The gate is a simulation control, not an automatically created fence mesh.
- **Water pasture** consumes twenty water; **Apply compost** consumes two mature compost. **Reseed** needs grazing closed, low cover and one seed; it establishes 25 seedling-cover units. Resting improves sward recovery and reduces compaction.

Standing grass is live modeled biomass, not a prebuilt mesh inventory. Pasture uses shared climate formulas but its own local clock; it does not introduce a global weather server. Build visible grass/gates separately from these scripts.

## Upgrade and verification

Field schemas 1/2 migrate to schema 3. Former unused slots become runoff and cell-application state, with no change to existing stocks, outbox or receipts. Machine schema 1 migrates to schema 2 by inserting equipment/hopper fields before its old outbox. Both preserve the existing data keys and save migrations atomically. Other module state layouts are unchanged.

Automated tests execute the actual LSL and cover full spreading coverage, rotated coordinates, lost request/ACK, moving/restarted senders, failed saves, capacity reservations, overapplication, leaks, separator resources, pasture/hay chains, physical control routing and stale indicators. Simulator vehicle behavior, Mono memory, gauge appearance and live hardware/mesh interaction remain pending in-world tests.
