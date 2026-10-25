# Expansion workflows and model parameters

## Production recipes

Select **Recipe**, deliver ingredients and utilities, then **Run batch**. Inputs are debited and output space reserved in one save. Reset resumes that batch. A second click cannot start another copy. Completion credits output once. Utilities can run out and pause progress; recipes cannot change mid-batch.

| Recipe | Inputs | Output | Productive farm days |
| --- | --- | --- | --- |
| Feed mill | 6 wheat + 2 soybean + 2 hay | 10 feed | 0.25 |
| Wheat dryer | 10 wet wheat | 8 wheat | 1 |
| Corn dryer | 10 wet corn | 8 corn | 1 |
| Flour mill | 10 wheat | 8 flour | 0.25 |
| Dairy | 10 milk | 1 cheese | 1 |
| Baler | 10 grass | 6 hay | 0.5 |
| Silage clamp | 10 grass | 8 silage | 7 |
| Digester | 10 slurry | 8 digestate + 1 biogas | 3 |
| Packhouse | 10 potato | 9 packaged produce | 0.25 |
| Slurry mixer | 5 manure + 5 water | 8 slurry | 0.1 |

Non-silage recipes consume four local energy units per productive farm day; dryers also consume two diesel units. DPC mode uses current appliance availability instead of debiting local energy. Wear at 95% stops processing; **Service** consumes one parts unit. Byproducts/moisture/process losses are accounted as normalized game units, not exact food-processing chemistry. **Generate power** consumes one biogas for three local energy units, increasing wear; it is disabled in DPC mode.

The processor has no automatic input-stock spoilage. Use Storage for modeled spoilage/refrigeration. A packhouse output is a ledger quantity, not a delivered Second Life inventory object.

## Storage and logistics

Storage holds the material catalog, exposes **Inventory**, **Select material**, load-size selection and **Send load**. Capacity is a sum of normalized inventory units, including outgoing reservations. A local pending load occupies capacity until acknowledgment. Cold storage uses two energy units per farm day and reduces the modeled decay rate to 15% of ambient. No energy means ambient decay.

The catalog includes crops, wet grain, hay, silage, feed, water, bedding, manure, compost, slurry, digestate, biogas, energy, diesel, seed, fertilizer, parts, medicine and processed products. Water, milk, diesel and slurry use roleplay litres; energy uses kWh; eggs use counts; other materials use roleplay kilograms. Mixed-unit capacity is a gameplay limit, not a physical trailer mass.

Set source **Settings → Destination** to a receiver root UUID. A source has only one pending load at a time. Ordinary farm material delivery is same-owner, same-region and within eight metres. Bound-cell spreading has a separate 40 m allowance; see FIELD_OPERATIONS.md. A Storage controller may represent a parked trailer, but hitching/towing and inventory ownership transfer are separate future work. Destinations accept only relevant materials; unsupported loads remain reserved until the receiving setup is corrected.

## Individual livestock

The original `Livestock` controller remains a simple cohort model. The new `Herd` controller stores up to eight individual records. Do not combine them in the same linkset or duplicate their accounting for the same roleplay animals.

| Species | Adult age, game days | Gestation/incubation | Modeled litter | Adult daily feed |
| --- | --- | --- | --- | --- |
| Cattle | 540 | 283 | 1 | 20 |
| Chicken | 150 | 21 | 4 | 0.15 |
| Sheep | 365 | 147 | 2 | 2 |
| Pig | 240 | 114 | 4 | 4 |

These defaults are game approximations. Actual lifecycles vary by breed and conditions; there is no simulated veterinary diagnosis or calibrated ration formulation.

Every record retains a UUID, name, sex, age, weight, welfare, parent IDs, inherited vigor and pregnancy/lactation state. **Manage** adds sandbox adults; **Animals** selects one; **Rename** names it. **Breed** requires a healthy adult female and a healthy, low-stress adult male of the same species. Parent/offspring and shared-parent pairs are blocked. Deeper ancestry is not traversed.

Birth/hatching creates new records with parent IDs and inherited vigor. Young age and weight advance and food demand scales with maturity. A full pen holds the due litter until there is room. Cows produce milk during lactation, adult hens lay eggs, and adult sheep produce wool. Pigs produce offspring and manure, with no meat/slaughter system. These are records, not automatically rezzed animal meshes.

Feed and water are finite and shared across living animals. **Grazing** consumes delivered grass before mixed feed; it does not itself discover or grow pasture. The separate Pasture controller now supplies finite grass through the existing delivery protocol. Poor care reduces health and can cause permanent death. **Treat** consumes medicine on a living animal. **Remove dead** removes active records with no product or money credit. It is not a complete historical pedigree archive.

## Irrigation

Set the pump destination to the field and enable the field's **Auto water**. The pump fills that field's finite tank; the field decides when to irrigate crops. A successful dispatch reserves 20 litres, consumes local energy unless DPC is enabled, and records wear. Modeled pressure decreases with distance and uphill head. Closed valve, depleted power/water, low pressure, worn pump or a pending load stops new pumping.

**Leak test** deliberately introduces a 20% training leak: delivery still reserves 20 litres but the tank loses 25, recording five spilled. Turn the pump off and **Repair** with one part. Hose geometry, rainwater catchment and real fluid networks are not supplied.

## Farm board and work orders

Board **Add node** registers same-owner roots within 96 m. It polls registered nodes, correlates replies to its query nonce and shows the selected node's state. Readings older than 60 seconds are marked stale. It is a monitor, not a remote control panel or global database.

Office **New work order** accepts `title|assigned-avatar-UUID`; omit the UUID to assign the owner. **Next job**, **Start job** and **Finish job** manage the selected order. Completion is an owner/assigned-worker report, not automatically inferred from tractor coverage. Enable `GROUP_WORK` for eligible group workers. Only the owner can prepare invoices. Sixteen records are retained, with no automatic deletion; start another office when the ledger is full.

Service invoicing is optional. It does not sell commodities, fulfill cross-owner goods, create public market prices or pay wages. See [INTEGRATIONS.md](INTEGRATIONS.md) for the confirmed-bank-status boundary.
