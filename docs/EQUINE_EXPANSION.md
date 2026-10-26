# Dream Farming — Horses and Donkeys Expansion

Status: **approved specification; not yet implemented in the existing LSL Herd controller or verified in Second Life.**

## Species
Add `horse` and `donkey` to the individual-animal species catalog. Both use the existing welfare, water, feed, manure, parentage, maturity, mortality and finite pasture systems. They do not produce milk/eggs/wool in the default farm economy.

| Parameter (game defaults) | Horse | Donkey |
| --- | --- | --- |
| Adult maturity | 1,095 game days | 1,095 game days |
| Gestation | 340 days | 365 days |
| Typical foals | 1 | 1 |
| Daily forage equivalent | 10 units | 6 units |
| Water/day | 30 litres | 20 litres |
| Products | Manure, used bedding | Manure, used bedding |
| Roles | Riding, draft, hauling | Pack hauling, draft, guarding roleplay |

Defaults are adjustable gameplay approximations, not veterinary or nutritional guidance.

## Behaviors and controls
- Feed/hay, water, grooming, hoof care, veterinary treatment, shelter, turnout, rest and fatigue.
- Age, sex, parent IDs, breeding cooldown, pregnancy, foaling, young-animal growth and death.
- Tack inventory: halter, lead, saddle, harness, bridle, cart attachment; validate ownership and compatible equipment before activation.
- Riding and pulling are separate optional modules. No claim that an unrigged mesh can walk or that LSL can bypass parcel/physics limits.
- Donkey braying, horse neighing, grazing, drinking, resting and idle animations are optional assets with toggles.
- Manure flows into the existing manure/compost system; each deposit is accounted exactly once.
- Each animal record carries species, breed, coat, owner farm ID, stable/pasture assignment and operational status.

## Non-rigged mesh workflow
1. Import user-owned OBJ/FBX/GLB into Blender and inspect topology, scale, normals, UVs and licenses.
2. Create an SL-compatible DAE mesh with appropriate LODs and physics shape.
3. Static display can use an unrigged mesh. Walking/riding animation requires a compatible rig/animation workflow or a documented alternative, tested in-world.
4. Keep scripts in the root/controller prim, mesh components separate where useful, and retain owner access controls.

## Engineering tasks
1. Extend Herd species enums, serialization and schema migrations without invalidating existing cattle/chicken/sheep/pig records.
2. Add horse/donkey gestation, foaling, feed/water/manure calculations and breeding tests, including parentage checks.
3. Introduce a stable/pen object and pasture interface, plus optional tack and hauling adapters.
4. Extend Cloudflare telemetry `kind: "livestock"` with per-species counts, ensuring counts are not double counted across herd controllers.
5. Add dashboard cards and filters for horses and donkeys, and historical births, health and manure charts after authoritative reporting exists.
6. Run LSL compiler/unit tests and in-world animal/mesh/parcel tests before declaring release ready.
