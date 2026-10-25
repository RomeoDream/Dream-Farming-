# Changelog

## 0.3.0 field operations alpha — 2026-10-25

- Added manure containment with weighted storage age, rain cover, overflow/leak losses, finite agitation/separation and parts-based liner repair.
- Added pasture biomass, climate-dependent regrowth, residual protection, low-cut confirmation, reseeding, resting and finite grazing/cut-grass exports.
- Added measured Machine spreading with a 500-unit hopper, four materials, three dose sizes, persistent per-job coverage and fixed-cell delivery retries.
- Added field nutrient/organic-matter effects, cell overapplication pressure, runoff and crop stress, with atomic application receipts.
- Added PTO/hydraulic/hitch interlocks, working-speed caps, filter wear, hydraulic fluid and a serviceable hour meter.
- Added named physical cab switches, state/fault indicators and local fuel/wear needles; stale telemetry is explicitly indicated.
- Added atomic Field schema 1/2 to 3 and Machine schema 1 to 2 migrations. Existing material/transaction identities are retained.
- Seventeen scripts compile locally; all 135 source-executing tests pass. In-world physics, gauges and Mono memory remain unverified.

## 0.2.0 expansion alpha — 2026-10-25

- Expanded five generated scripts to fourteen, retaining the existing field, cohort livestock, compost and visual paths.
- Added individual herds with names, sex, growing offspring, pedigree and inherited vigor; finite animal-product exports.
- Added stock depots, refrigeration, ten production recipes, slurry/digestate/biogas and local biogas energy generation.
- Added a physical tractor driver, fuel authorization controller and persistent 8×8 field-work coverage for four implements.
- Added soil types, optional sowing windows, wet-grain exports and atomic Field schema-1 migration.
- Added pump/valve/leak/repair simulation, a farm monitor, work orders and optional group care permissions.
- Added current Garden manure-producer integration. Retained the older applicator strictly for Garden v0.3.
- Added optional existing-protocol TXAGO, DPC and Dream Banking adapters, with explicit authority and configuration boundaries.
- Added source-executing tests and setup/integration/acceptance documentation. Simulator and asset qualification remains outstanding.

## 0.1.0 alpha — 2026-10-25

- Initial local LSL fields, soil/climate, cohort animals, manure/compost, durable material transport and legacy Garden applicator.
- Added generated-file checks, Lummao compilation and 54 behavior tests, passing locally and in GitHub Actions.
