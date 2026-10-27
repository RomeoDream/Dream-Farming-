# In-world setup — expansion alpha

Rez test objects on land where you may build, run scripts and enable physics. Paste complete files from `lsl/` into Mono scripts. Put each controller in the root, with one farming controller per linkset. Driver/visual scripts and documented external adapters are companions.

## Object layout

| Object | Root scripts | Configuration |
| --- | --- | --- |
| Field | `DreamFarm_Field`; optional `DreamFarm_Visuals` | Default 20×20 m working rectangle centered on root, local X/Y axes |
| Tractor | `DreamFarm_Machine` + `DreamFarm_TractorDriver`; optional `DreamFarm_Cab` | Same root; root +X forward; owner sits on root |
| Storage shed or parked trailer | `DreamFarm_Storage` | One stock ledger; do not add Machine to this linkset |
| Processing building | `DreamFarm_Processor` | Select a recipe; one batch at a time |
| Equine stable | `DreamFarm_EquineStable` | Separate root; see SL_TEST_CANDIDATE.md |
| Cloud telemetry | `DreamFarm_CloudSync` beside Herd, Field or Machine | Optional private per-object token; disabled by default |
| Individual-animal pen | `DreamFarm_Herd` | Manage adds sandbox adults; maximum eight records |
| Original cohort pen | `DreamFarm_Livestock` | Optional simpler pen; set species before first boot |
| Manure pit/tank | `DreamFarm_ManureStore` | Finite containment, leakage, cover and separation |
| Pasture | `DreamFarm_Pasture` | Standing grass, mowing, regrowth and optional herd supply |
| Compost pile | `DreamFarm_Compost` | One active/curing batch |
| Water pump/tank | `DreamFarm_Irrigation` | Destination field UUID; enable field irrigation separately |
| Farm monitor | `DreamFarm_Board` | Up to 16 same-owner roots within 96 m |
| Farm office | `DreamFarm_Office` | Up to 16 retained work orders; optional banking |
| Current Garden collection point | `DreamFarm_Garden_Link` + upstream `DreamGarden_FarmManure` | Same root; Garden `ANIMALS=0`; automatic bridge |
| Legacy Garden v0.3 applicator | `DreamFarm_Garden_Applicator` | Only the pinned older Botany interface; see manure guide |

Touch controllers within 8 m. With `GROUP_WORK=TRUE`, members wearing the object's non-null group may perform selected care and work-order actions; the owner retains transfers, configuration and sandbox restocks. This is coarse group access, not a full employment system.

## First connected farm

1. Put a Field, Herd, Compost, Processor and Storage within transfer range. Register their root UUIDs at a Board.
2. Field: **Plow → Plant → Wheat**. Manage **Soil care** and **Utilities**. **Settings → Demo x60** accelerates both growth and damage.
3. Herd: **Manage → Cow**, **Manage → Bull**, then **Manage → Sandbox supplies**. Select the cow under **Animals**. Naming, breeding and treatment affect the selected record.
4. Set herd **Settings → Destination** to the compost root UUID. **Export → Select material → Manure → Send 10** moves finite stock. Material selectors use **Next** for later pages.
5. Compost: start a recipe, manage moisture/oxygen, finish active processing and curing, then send mature compost to the field. **Soil care → Compost** consumes it.
6. Field: harvest when ripe. **Export harvest → Wheat** sends ten wet-wheat units to the destination Processor. Select **Wheat dryer**, supply energy/diesel, and **Run batch**.
7. Export dry wheat to storage or mill it into flour. Several processors form a production line; one can switch recipes after completing a batch.

Initial stock and sandbox deliveries are game supplies. They do not represent a purchase, payment or verified commodity provenance.

## Tractor build and use

Start with a simple low-complexity physical linkset and stable collision hull. Decorative meshes, wheels and implements are separate asset work. The driver sets a root sit target at local `<0,0,0.6>` and basic CAR physics parameters.

1. Place both tractor scripts in the same root. Owner sits, grants controls and drives with arrow/WASD controls. Travel target is 4 m/s, reverse at most 2 m/s; lowering an implement applies its slower working cap; actual movement depends on terrain and simulator load.
2. Set Machine **Settings → Destination** to the field root UUID.
3. Select **Implement**, optionally **Crop**, lower it with **Lower or raise**, and turn **Engine** on. Harvest/Spread also require **Cab controls → PTO**. See [FIELD_OPERATIONS.md](FIELD_OPERATIONS.md) for spreading and interlocks.
4. Drive over each 2.5×2.5 m cell. Coverage uses actual object position/velocity, accepts 0.2–4 m/s and a vertical difference up to 4 m. Drive slowly with overlap.
5. At 64/64 the field performs the operation once and the implement raises. Sowing also needs a tilled empty field, field seed stock and an allowed season. Harvesting needs ripe crops and storage room.
6. **Utilities → Field setup → Reset coverage** abandons unfinished coverage without producing anything or refunding fuel. Then start a new machine job.

Coverage survives reset. Machine reset stops the requested engine, requiring manual restart. Driver leases expire after two seconds without confirmation. Unseating and region changes stop the driver. Towing, animated implements, physical hitch attachment, load-dependent vehicle mass and collision feedback are not implemented.

## Time and resources

- Normal: one real hour = one farm day. Demo x60: one real minute = one farm day.
- Normal slices are 150 seconds; demo slices five seconds. Controllers process at most eight slices per event, normally on a 15-second timer.
- At most 24 real hours of offline time is simulated; excess is recorded as frozen time. Each field starts its own 120-day seasonal year.
- Driver fuel leases and pump throughput use real seconds, independent of crop speed. Pump and processing resource values are roleplay budgets.
- Pause freezes simulation progression; previously reserved transfers can finish. Pending stock is never automatically refunded.

## Persistence and upgrades

Reset preserves Linkset Data. Field v0.1/v0.2 migrates to schema 3 and Machine v0.2 to schema 2, preserving stock, outbox and receipt identities. Migration is saved atomically before operation. Other existing module schemas remain unchanged. Install new modules in fresh linksets.

Keep ordinary delivery endpoints within 8 m (spreading uses its bound field cell and 40 m allowance), rezzed and running until confirmed. Do not clear receipts, copy live economic objects or relink pending roots as a repair. Each receiver retains eight sender streams; arrange depots/additional receivers before reaching that limit. Deleted destinations and owner changes require audited recovery.

Run [IN_WORLD_TESTS.md](IN_WORLD_TESTS.md) before calling an installation production-ready. Every script needs Mono compilation, actual memory measurements and simulator checks.
