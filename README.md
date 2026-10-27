> **SL test candidate:** Start with [SL_TEST_CANDIDATE.md](docs/SL_TEST_CANDIDATE.md). The active Stable is now generated in `lsl/`, alongside the optional CloudSync companion. Use the downloadable workflow artifact or run `python tools/package_beta.py` for the complete test package. This is controlled-test readiness, not production certification.

# Dream Farming

**Second Life farming simulation for Romeo Dream — 0.3.0 field operations alpha.**

Seventeen paste-ready LSL scripts connect crops, machinery, individual animals, manure, compost, storage, processing, irrigation and farm management. The core runs inside Second Life without an external server. Optional adapters use the existing Dream-Garden, TXAGO, Dream Power Company and Dream Banking interfaces.

**This is an implemented and locally tested scripting expansion. Second Life Mono memory, vehicle physics, live integrations and finished visual assets still require in-world qualification.** Realism is a configurable roleplay model; quantities and times are not agricultural or veterinary advice.

## Included systems

| System | Implemented behavior |
| --- | --- |
| Fields | Six crops, thermal growth, N/P/K, pH, organic matter, compaction, water balance, weeds, pests, disease, repeat-crop penalty, seasons and optional sowing windows |
| Soil and climate | Loam/clay/sand water retention, frost/heat stress, greenhouse climate control, finite tank irrigation and local or DPC power |
| Tractor and implements | Owner driving/steering, saved fuel leases, wear/repair, plow/sow/harvest/weed modes, actual-position 8×8 field coverage, measured spreading, PTO/hydraulic/hitch interlocks and cab controls |
| Individual animals | Up to eight named cattle/chickens/sheep/pigs per herd; sex, age, weight, health, feed/water, parentage, inherited vigor, mating, birth/hatching, maturation and death |
| Animal products | Milk, eggs, wool, manure and used bedding; finite export to other farm objects |
| Waste and compost | Manure storage, leaks/overflow, separation, measured field application, three managed compost recipes and mature fertilizer |
| Pasture | Regrowth, weather stress, protected residual, mowing, reseeding, resting and finite grass deliveries to herds |
| Processing | Feed, grain drying, flour, cheese, hay, silage, slurry, digestate, biogas and packaged potatoes; reserved inputs/output capacity, energy and wear |
| Storage | Material selection, loading/unloading, finite capacity, spoilage and powered refrigeration; depot or parked trailer controller |
| Irrigation | Finite water/energy, pump and valve, distance/head pressure, modeled leakage, repairs and reliable field-tank deliveries |
| Management | Registered-object monitoring board, stale-reading detection, persistent work orders and opt-in group workers |
| Optional integrations | Current Garden manure producer bridge; TXAGO engine authority; DPC appliance demand; Dream Banking service invoices |
| Reliability | Atomic saves, durable transfer reservations/receipts, retry deduplication, bounded catch-up, invalid-record lockout and Field/Machine migrations |

**Manure cycle:** animal feed → manure + bedding → managed compost → mature fertilizer → soil → crops → feed. A second route converts manure + water into slurry, then digestate + biogas; digestate can enter compost, and biogas can generate local energy.

## Get started

1. [Setup and object layout](docs/SETUP.md) — paste files from [lsl/](lsl/) into test objects.
2. [Expansion walkthrough](docs/EXPANSION.md) — animals, machinery and production workflows.
3. [Manure and Garden compatibility](docs/MANURE_AND_GARDEN.md) — current Garden and legacy paths differ.
4. [Optional integrations](docs/INTEGRATIONS.md) — exact APIs and configuration.
5. [Field operations](docs/FIELD_OPERATIONS.md) — manure storage, spreading, pastures and physical cab controls.
6. [Verification status](docs/STATUS.md) and [in-world acceptance checklist](docs/IN_WORLD_TESTS.md).

Core menus include clearly labeled sandbox deliveries. They create roleplay supplies without charging money. Bank invoices require explicit configuration and customer payment; totals are historical records, not spendable balances.

## Development

```sh
python -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-dev.txt
python tools/build.py
python -m unittest discover -s tests -v
```

Edit [src/](src/), then rebuild. Generated `lsl/` files need no in-world preprocessor. CI verifies generated copies, compiles every script with Lummao and executes actual LSL event handlers with mocked simulator services.

## Boundaries

Ordinary material deliveries are same-owner, same-region and within 8 m; bound-cell spreading uses a 40 m allowance. Both use eight retained sender streams per receiver. The board reads registered objects within 96 m. Pending deliveries are never automatically refunded. Copies of an object copy its stock; this is a cooperative farm, not a secure public economy.

Individual animals are persistent records; meshes and animations are separate. The vehicle driver needs a suitable physical build. Crop meshes, sounds, PBR materials, animated implements, hose meshes, transferable packaged inventory, public market trading and authoritative cross-region servers are not included. See [roadmap](docs/ROADMAP.md).

Project and creator credit: **Romeo Dream / RomeoDream**. Upstream Garden and Banking scripts are unchanged read-only test fixtures identified by Git blob SHA.
