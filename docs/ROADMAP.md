# Development milestones

## M1 — LSL local simulation (implemented, local tests passing)

Fields/soil/climate, six crops, finite resource consumption, equipment fuel/wear model, local storage/spoilage, four livestock species/cohorts, manure and bedding, managed composting, reliable local material delivery and existing Garden Botany applicator.

## M2 — In-world qualification (pending)

Compile in the Second Life Mono editor, measure runtime memory, verify real dialogs, reset/rez behavior, object UUIDs, actual chat timing and stage meshes. Tune growth and care workload using observed play sessions. Fix and record failures before adding scale.

## M3 — Farming depth and asset work (planned)

- Drivable tractors, implement attachment points, working-width field coverage and speed-sensitive jobs.
- Irrigation equipment, tanks and hoses with pressure/flow; external power/fuel adapters.
- Crop-specific meshes, PBR materials, particle effects, growth-stage assets and animal animations.
- Crop production chains, drying, hay/silage, milling, feed recipes and refrigerated storage.
- Variable compost recipe assembly, species-specific manure analyses, wet/dry mass, richer quality transfer and flexible batch sizes.
- Animal sexes, individual pedigrees/genetics, actual mating pairs, young maturation, replacement stock, grazing/pasture and manure spreading.
- Shared workers/groups and permissions; synchronized farm calendar; diagnostics and audible/visual alarms.
- More crops, orchards, orcharding tools, fencing, beekeeping/pollination and production buildings.

## M4 — Connected economy (deferred until APIs and server are chosen)

Authoritative persistent farm/entity records; versioned transactions with durable idempotency; auditable stock transfers; recovery after object deletion and identity changes; market offers, inventory packaging and cross-region logistics. Pair against the actual Dream Banking, TXAGO and Dream Power protocols. Do not invent compatibility or infer payments from local sandbox restock controls.

## Acceptance rule

A milestone is not verified merely because its scripts exist. Record automated checks, simulator tests and any unsolved limitations separately in STATUS.md.
