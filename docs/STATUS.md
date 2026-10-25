# Status — 2026-10-25

Version **0.3.0 field operations alpha**. Project and creator credit: **Romeo Dream**.

Seventeen generated LSL scripts implement the expanded local farm: six-crop soil/climate simulation, individual and cohort livestock, compost/manure flows, processing/storage, driving and field coverage, irrigation, monitoring, work orders and optional existing-protocol integrations. The core requires no external server.

The v0.3 milestone adds manure containment/separation, pasture growth and grazing supply, measured field spreading, PTO/hydraulic/hitch control interlocks, working-speed caps, machinery service state, and a physical cab companion. See FIELD_OPERATIONS.md for installation and the exact boundaries of these models.

## Verification

- Generated `lsl/` copies match their `src/` includes.
- All seventeen scripts compile through Lummao 0.5.2.
- The suite executes actual LSL events with mocked simulator builtins, storage, time, physics and message transport.
- Tests cover ordinary reset/persistence, invalid data, ownership/group access, failed writes, crop/soil behavior, births/pedigree/growth, input/output reservations, all ten recipes, biogas generation, pump conservation, machine coverage/fuel leases, driver expiry, stale board state and invoice idempotency.
- New tests cover spreading in rotated coordinates, full 64-cell coverage, losses before/after field receipt, moving/restarted sources, reserved hopper capacity, overapplication, manure leaks/separation, pasture/hay chains, cab command filtering and stale indicators.
- Garden tests run unchanged upstream Botany v0.3 and FarmManure v0.4 fixtures. Banking tests run the actual pinned Bill Terminal adapter with simulated bank responses. TXAGO and DPC tests exercise their inspected linked-message contracts; they do not run live servers or grids.
- Fixtures and exact upstream source identifiers are documented in MANURE_AND_GARDEN.md and INTEGRATIONS.md. No upstream repositories were modified.
- **135 tests pass locally**, using `python -m unittest discover -s tests -v`. This includes 31 new field-operation tests. GitHub verification of this new milestone is pending publication.
- Previous v0.2 expansion commit `a3f63777208a0356e0d1b4ab9a22b385bc9793b1` passed generated-file checks, compilation and all 104 tests: [successful GitHub Actions run 40193784462](https://github.com/RomeoDream/Dream-Farming-/actions/runs/40193784462).

## Not yet verified

Second Life Mono compilation and free memory, physical vehicle hull/handling, live viewer dialogs, simulator event timing/throttles, re-rez behavior, meshes/animation, real Garden compost completion, live TXAGO/DPC/bank interaction and multi-object performance. The explicit pending checklist is IN_WORLD_TESTS.md.

## Material boundaries

This is cooperative local roleplay. Ordinary deliveries are same-owner/same-region within 8 m; bound-cell spreading is allowed within 40 m, with eight durable source streams per receiver. No automatic refund is offered for a deleted or uncertain destination. Copies duplicate their economic state. The board is local, and each field has its own seasonal clock.

Animal records are individual but not rezzed meshes. The tractor driver is supplied without a finished physical/visual vehicle. Machine coverage is an 8×8 point-sampled grid, not continuous implement geometry. Stock uses normalized capacity with mixed RP units. Restocking is explicitly sandboxed. Office completion is a manual report; bank totals are history, not currency. Cross-owner goods sales, transferable inventory objects, towing, authoritative cross-region servers and a complete art package remain separate work.
