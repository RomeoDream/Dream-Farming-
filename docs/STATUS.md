# Status — 2026-10-25

Version **0.1.0 alpha**, project credit **Romeo Dream**.

Implemented: five paste-ready LSL scripts, persistent local farming/livestock/compost behavior, material transfer reservations and receipts, and the existing Dream-Garden Botany fertilizer bridge. No external server is required.

## Verification

- All five generated scripts compile with Lummao 0.5.2.
- Generated copies match source includes.
- Actual LSL behavior tests cover persistence, invalid records, ownership, resource consumption, crop growth/harvest, spoilage, animal production/births, compost maturity, replay/lost delivery, failed writes and Garden integration.
- Tests use an unchanged Garden Botany fixture at blob `e51355c56537c5ca6133a35db66382d03862c05b`.
- Current suite: **54 tests passing locally**. The test command is `python -m unittest discover -s tests -v`.
- GitHub Actions also passed compilation, generated-file checks and all 54 tests at commit `704b07f0342423254f99ab3bce37318c38648600`: [successful run 40188834982](https://github.com/RomeoDream/Dream-Farming-/actions/runs/40188834982). An initial cache-configuration failure was corrected by specifying `requirements-dev.txt`.

## Not yet verified

Second Life Mono compilation, actual free script memory, viewer menus, simulator throttles and message timing, live reset/rez behavior, meshes and multi-object performance. See IN_WORLD_TESTS.md.

## Material limitations

Owner-only operation; same-owner/same-region local transfers; eight durable sender streams per receiver; no automatic recovery from a deleted transfer destination. Copying an object copies its economic state. Garden timeouts hold a dose and require explicit discard without refund.

Field weather clocks start independently. Restocking and services are explicit roleplay controls with no charge; state counters are not bank balances. Young livestock are counts, not individual spawned animals. Equipment fuel/wear exists, but vehicle driving, working implements, asset models, connected banking/fuel/power and a server-backed market are future milestones.
