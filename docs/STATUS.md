# SL UUID registration update — 2026-10-27

New farm, owner and controller identities use SL UUIDs. A root registration companion automatically fills owner/root UUIDs, persists the Farm UUID and supports joining an existing farm. Controller menus expose the optional registration companion without a competing touch menu. Existing administrator login approves registration; UUIDs alone grant no access.

Migration 0004 adds UUID mappings without deleting old farm/account/inventory records. Explicit legacy mapping retains passwords, credentials and internal relationships in one transaction. Farm sign-in uses owner UUID, Farm UUID and the existing password. CloudSync reports owner/root UUIDs and the server rejects mismatches. The generated script set now contains 20 scripts.

Local validation: **184 Python/LSL runtime tests and 13 Worker/SQLite tests pass**, including real legacy-schema migration, transactional rollback and UUID account sign-in.

See [SL_REGISTRATION.md](SL_REGISTRATION.md) for installation and deployment order. No live Cloudflare migration/deployment or simulator verification has been performed by this code update.

---

# Second Life test candidate — 2026-10-26

The local farm and equine path are prepared for controlled SL installation. The active Stable is now `src/DreamFarm_EquineStable.lsl` → generated `lsl/DreamFarm_EquineStable.lsl`; the old experimental controller remains historical. The farm now supplies 19 standalone LSL scripts including the optional CloudSync companion.

Implemented in this candidate:

- Finite Herd → Stable manure delivery, muck-out collection and Stable → Compost export using the existing LOAD/ACK protocol.
- Atomic v4 Stable snapshots retain stock, destination, reservation and eight non-evicted manure receipts. V3 pending deliveries migrate to their original Herd target. Lost ACK, resets and save failures cannot intentionally credit a second load.
- Herd care reports rotate through verified Stable equines. Health, hunger, thirst and stress are observations; only Herd consumes supplies and creates manure.
- Owner-facing Animal IDs and Stable memory/receipt diagnostics support actual installation.
- Optional root CloudSync sends real living animals, planted fields and equipment counts. It is disabled without a private object token, reads server revisions, backs off, reconciles conflicts, and locks changed object/owner bindings. It never controls local stock.
- Worker credential rotation fixed; malformed JSON values rejected; dashboard excludes telemetry older than five minutes. Existing production data, bootstrap and artwork are preserved. Worker changes require separate deployment through the existing process.
- Reproducible ZIP packaging includes all source, generated scripts, tests, checksums, installation guide and a blank simulator result sheet. CI publishes it only after checks pass.

Local validation: **178 Python tests and 6 Worker API tests pass**; all 19 generated LSL scripts compile through Lummao 0.5.2 and generated-file checks pass. Second Life compilation is not claimed.

Validation evidence is the candidate commit's GitHub Actions runs and packaged source manifest. Lummao and SQLite tests are local substitutes for compiler/runtime and database behavior, not evidence of successful Second Life Mono compilation or live D1 deployment.

**Next gate is owner-run SL testing:** [installation and test order](SL_TEST_CANDIDATE.md). Memory at eight animals/full receipt tables, physical tractor behavior, real timers/HTTP, region restarts, meshes and live Garden/TXAGO/banking need recorded simulator results. Authoritative cross-owner inventory, riding/hauling and finished animal meshes are outside this local test candidate. The 100-stage program is not claimed complete.

---

# Beta hardening update — 2026-10-26

The equine hardening batch replaces multi-key Stable writes with validated atomic snapshots, locks copied/other-owner records, preserves pending transactions through save failures, removes an invalid LSL ternary expression, and fixes horse/donkey zero-litter births. Eleven new runtime tests exercise the actual Stable and Herd scripts. The equine workflow now installs the compiler/runtime dependency.

Validation: generated-file check and all **163 local tests pass** with Lummao 0.5.2. The previous head (`22e43de`) had one failing brittle source assertion; it is replaced with snapshot identity/rollback checks and behavioral tests. GitHub Actions results for this batch must be checked on its commit. Second Life Mono compilation, memory and in-world tests remain outstanding. Cloudflare deployment and existing production records were not changed.

The 100-stage program remains a target; this batch does not qualify the complete beta. Stable manure export, complete welfare synchronization, server-authoritative inventory and live integration remain blockers. Details: [equine transfers](EQUINE_WATER_TRANSFER.md).

---

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
- **135 tests pass locally and in GitHub Actions**, using `python -m unittest discover -s tests -v`. This includes 31 new field-operation tests.
- Field-operations commit `a7b11a48f12d561eefe4d37b50d3f3f20fa3140b` passed generated-file checks, compilation and all 135 tests: [successful GitHub Actions run 40238467507](https://github.com/RomeoDream/Dream-Farming-/actions/runs/40238467507).
- Previous v0.2 expansion commit `a3f63777208a0356e0d1b4ab9a22b385bc9793b1` passed generated-file checks, compilation and all 104 tests: [successful GitHub Actions run 40193784462](https://github.com/RomeoDream/Dream-Farming-/actions/runs/40193784462).

## Not yet verified

Second Life Mono compilation and free memory, physical vehicle hull/handling, live viewer dialogs, simulator event timing/throttles, re-rez behavior, meshes/animation, real Garden compost completion, live TXAGO/DPC/bank interaction and multi-object performance. The explicit pending checklist is IN_WORLD_TESTS.md.

## Material boundaries

This is cooperative local roleplay. Ordinary deliveries are same-owner/same-region within 8 m; bound-cell spreading is allowed within 40 m, with eight durable source streams per receiver. No automatic refund is offered for a deleted or uncertain destination. Copies duplicate their economic state. The board is local, and each field has its own seasonal clock.

Animal records are individual but not rezzed meshes. The tractor driver is supplied without a finished physical/visual vehicle. Machine coverage is an 8×8 point-sampled grid, not continuous implement geometry. Stock uses normalized capacity with mixed RP units. Restocking is explicitly sandboxed. Office completion is a manual report; bank totals are history, not currency. Cross-owner goods sales, transferable inventory objects, towing, authoritative cross-region servers and a complete art package remain separate work.
