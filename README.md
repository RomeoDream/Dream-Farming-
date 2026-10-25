# Dream Farming

**Second Life farming roleplay, created for Romeo Dream. Version 0.1.0 alpha.**

This repository contains LSL source for a serverless farming prototype. Automated tests execute the actual LSL event handlers through Lummao with mocked Second Life services. **Second Life Mono compilation, script memory, simulator timing and mesh operation still require in-world testing.** This is an alpha foundation, not a finished commercial farming game.

## Implemented

| Component | Behavior |
| --- | --- |
| Fields | Wheat, corn, soybean, potato, sunflower and grass; tilling, sowing, thermal growth, harvest, seed return and crop residue |
| Soil | Water balance, drainage/leaching, N/P/K fertility, pH, organic matter, compaction, weeds, pests, disease and repeat-crop penalty |
| Climate | Seasonal temperature/rain/light, frost/heat damage, greenhouse shelter, powered conditioning and tank-fed irrigation |
| Equipment model | Diesel use and wear for plowing, sowing and harvesting; service/refill controls. No drivable vehicle supplied yet |
| Storage | Persistent crop quantities, ambient spoilage and local roleplay consumption |
| Livestock | Cattle, chickens, sheep and pigs; feed/water use, hygiene, stress, health/death, milk/egg/wool, pregnancy/incubation and offspring counts |
| Waste | Collect and transfer fresh manure, used bedding and dry crop residue to compost |
| Compost | C:N recipe, moisture, oxygen, temperature, turning, mixer wear, active breakdown, separate curing, mass loss and mature stock |
| Garden integration | Mature compost applicator using Dream-Garden Botany's existing MANURE interface |
| Reliability | Atomic whole-object saves, failed-write rollback/lockout, durable outgoing loads, receiver sequence receipts and bounded offline catch-up |

**Manure cycle:** feed livestock → muck out → transfer manure/bedding → manage compost → cure → deliver mature compost → fertilize a field or Garden plant. Fresh manure cannot be exported as mature compost. Timelines and material values are game parameters, not agricultural recommendations or pathogen-safety claims.

## Start here

1. [SETUP.md](docs/SETUP.md): build simple test objects and paste scripts from [lsl/](lsl/).
2. [MANURE_AND_GARDEN.md](docs/MANURE_AND_GARDEN.md): waste cycle and exact Garden compatibility.
3. [IN_WORLD_TESTS.md](docs/IN_WORLD_TESTS.md): acceptance checklist before a live farm.
4. [STATUS.md](docs/STATUS.md): verification and remaining work.

No server, database, API key or payment account is needed. One controller belongs in each root prim. State stays in its linkset data store. Optional visuals switch named crop-stage children; meshes, materials, sounds and animal animations are not included.

## Development

```sh
python -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-dev.txt
python tools/build.py
python -m unittest discover -s tests -v
```

Edit [src/](src/) then rebuild. Files in `lsl/` paste directly into the Second Life script editor without a preprocessor. CI checks generated copies and runs compilation and behavior tests.

## Scope

Owner-only menus, same-owner local material transfers and explicit roleplay restocking are implemented. This version does not debit money, deliver transferable inventory, authenticate modified clients, prevent object-copy duplication, or communicate across regions. No automatic Dream Banking, TXAGO or Dream Power connection is claimed. Those adapters require their actual protocols and independent integration tests. See [ARCHITECTURE.md](docs/ARCHITECTURE.md) and [ROADMAP.md](docs/ROADMAP.md).

Original project and creator credit: **Romeo Dream / RomeoDream**. Dream-Garden's original code is unchanged; its read-only test fixture retains its header and is identified by upstream blob SHA.
