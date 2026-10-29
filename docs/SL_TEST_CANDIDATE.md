# Dream Farming — Second Life test candidate

Project and creator: **Romeo Dream**. This package is ready to begin controlled SL testing. It is not a production economy or a simulator-qualified release. Start on a separate test plot with fresh objects and sandbox stock. Existing live farm, administrator login and approved dashboard artwork need no reset.

## Install the first five objects

Use files from **lsl/**, which are complete standalone scripts. The files under src/ contain development sources; do not paste those instead. Historical experimental Stable files are not the active version.

| Fresh object | Root scripts | First action |
|---|---|---|
| Animal pen | DreamFarm_Herd.lsl | Manage → Equines → Mare; repeat for Stallion (or Jenny and Jack) |
| Stable | DreamFarm_EquineStable.lsl | Set Herd → paste animal pen root object UUID |
| Compost pile | DreamFarm_Compost.lsl | Leave filling while manure arrives |
| Field | DreamFarm_Field.lsl | Plow → Plant → Wheat |
| Farm monitor | DreamFarm_Board.lsl | Register each root using its existing menu |

Keep transfer roots **within 8 m**, same owner and region. Put one controller in each root. Keep the Stable in a separate object from Herd and Compost. Compile all as **Mono** in Firestorm. If any script fails compilation or throws a runtime error, stop that test and record the complete error and filename; do not erase Linkset Data to fix it.

Herd → Settings → Sandbox supplies provides test feed, water, bedding and medicine. These are roleplay supplies; no purchase or bank debit is claimed. Individual animals are persistent records: meshes, animal walking, riding and hauling are separate visual/vehicle work.

## Stable feed, water and animal care

1. Stable: Add water, Add hay. Send water; More → Send feed. Only one outgoing delivery can be pending. Timer retries normally take up to 60 seconds.
2. Compare inventories: each accepted delivery adds 10 WATER/FEED to Herd and subtracts 10 local Stable water/hay after its ACK. Do not let a simulation tick obscure the comparison: pause Herd first, reserve/send, then resume to receive a new load. Existing receipt retries may ACK while paused; a new load waits for resume.
3. Find an animal UUID in the Herd saved record or via the diagnostic method below. Stable → Assign UUID. A living horse/donkey must be verified by the configured Herd.
4. Care on polls one assigned animal per minute, rotating through up to eight. Status shows the most recent animal's health, hunger, thirst and stress with its report age. A missing/dead animal is reported unavailable; it is not replaced or resurrected. Care monitoring does not consume Stable stock independently.
5. Breed from the selected adult female. Normal clock is one real hour per farm day; Demo x60 is one real minute per farm day. Gestation: horse 340 days, donkey 365 days. Keep food/water available; do not skip welfare management during a long demo.

To obtain test animal UUIDs without changing stock, use the **Animal IDs** button under Herd → Equines. Copy the desired UUID from owner chat. Never use an avatar or mesh UUID as an animal record UUID.

## Manure chain

1. Stable → More → Set compost → paste Compost root object UUID.
2. Herd → Settings → Destination → paste Stable root UUID. Herd → Export → Select material → Manure → Send 10. Herd must have at least 10 manure units from actual feeding.
3. After ACK, Stable Status shows 10 received manure. Muck out moves it to local collected stock without creating additional manure.
4. Stable → More → Send manure. The fixed 10-unit load is reserved for the configured Compost. After confirmation, collected stock falls by 10 and Compost fresh manure rises by 10.
5. Compost → Balanced batch consumes 10 manure plus 10 browns. Turn pile and manage moisture/oxygen through active processing and curing. Send compost to a Field or the documented Garden bridge only after maturity.

Herd may also send directly to Compost or ManureStore using the existing destination/export menus. These are alternate routes: never credit both routes manually for the same stock.

## Reset and failure tests

- Pause a receiver, reserve a load, reset sender, resume receiver: one load arrives.
- Move receiver beyond 8 m with a delivery pending; it remains reserved. Return within range: it finishes once.
- Reset both scripts after a completed delivery: quantities do not increase again.
- Change a destination while pending: rejected. There is no automatic refund for an uncertain destination.
- Copy a Stable with stock: the copy must lock. A re-rez that changes object UUID also locks for reconciliation. Keep active roots rezzed during this test.
- Test foreign-owner objects: no deliveries or animal verification.
- Stable → More → Diagnostics and each controller → Settings → Diagnostics: record free Mono memory with maximum expected records, not only an empty object. Stop on Stack-Heap Collision, locked state or declining memory under repeated use.
- Test all dialogs on the actual viewer. Record simulator timing, region restart behavior and simultaneous farm activity.

Use SL_TEST_RESULTS.csv for outcomes. Local runtime simulation covers dropped ACKs and failed persistent writes; actual simulator behavior remains unverified until you run it.

## Optional tractor and processing tests

Install Machine + TractorDriver in one fresh root; Cab and Visuals are optional companions. See SETUP.md and FIELD_OPERATIONS.md for sit controls, engine/fuel, PTO/hydraulic/hitch interlocks, 8×8 field coverage, processing and finite manure application. Use a simple physical test build before attaching detailed mesh. Reset/unseat must stop movement. Garden, TXAGO and banking adapters are optional and each requires its own live acceptance test.

## Second Life UUID registration

The current package adds `DreamFarm_Register.lsl` as the twentieth standalone script. See [SL_REGISTRATION.md](SL_REGISTRATION.md) for owner/root UUID detection, farm joining, administrator approval and non-destructive legacy mapping. Registration requires migration 0004 and the matching Worker deployment; local three-prim farming still works without registration.

## Optional Cloudflare telemetry

Local farming works without this script or an internet connection. Install **one CloudSync companion** beside a Herd, Field or Machine root controller, not beside every prim. Leave disabled unless using a privately provisioned per-object credential. Never place ADMIN_TOKEN or administrator password in a Second Life object.

The existing /v1/admin/enroll API provisions a unique object credential. An administrator can use that existing endpoint; no new administrator bootstrap or database reset is required. Configure API_URL and OBJECT_TOKEN privately in CloudSync. For test isolation use a fresh enrolled object ID and do not reuse a production controller credential.

CloudSync reads server revision before posting, sends real living-animal/active-field/equipment counts, backs off on failure, reconciles revision conflicts, and stops on rejected credentials or changed owner/object identity. It never changes local inventory. A stale/faulted controller stops reporting. The dashboard update in this branch excludes telemetry older than five minutes; deploy Worker code separately through the existing Cloudflare process when testing that change. No live deployment is claimed by this package.

## Release boundary

The automated gates check generated files, compile all packaged LSL with Lummao, execute actual LSL behavior with simulator builtins mocked, and run Worker API tests against SQLite. Those results do not certify Second Life Mono memory, physics, HTTP throttles, meshes, or live services. Do not sell copied sandbox stock or treat local ledgers as server-authoritative cross-owner inventory. Log defects against this candidate's source commit from MANIFEST.json.
