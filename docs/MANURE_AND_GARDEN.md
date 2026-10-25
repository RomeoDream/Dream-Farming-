# Manure, compost and Dream-Garden

Animals consume feed/water and generate `MANURE`. Cleaning consumes bedding and retains `BROWNS`; fields also provide dry residue. Only completed, cured farm compost is exported as `COMPOST`.

## Farm compost recipes

| Menu choice | Inputs | Modeled initial C:N | Mature output |
| --- | --- | --- | --- |
| Start batch | 10 manure + 5 browns | About 23.3 | 8.25 compost |
| Balanced batch | 10 manure + 10 browns | About 30 | 11 compost |
| Leaf batch | 10 manure + 20 browns | About 40 | 16.5 compost |

Inputs are consumed atomically. Moisture, oxygen, temperature and balance determine productive decomposition. Turning restores oxygen and wears the mixer; watering uses tank water. Seven productive active days precede seven suitable curing days. Neglect takes longer. Mature yield is 55% of initial recipe mass.

Fields consume two mature units per application, improving nutrients and organic matter. Their compost inlet rejects raw manure. `DIGESTATE` is accepted as a raw compost ingredient, not automatically credited as mature fertilizer.

Processor **Slurry mixer** consumes five manure + five water to make eight slurry. **Digester** consumes ten slurry to produce eight digestate + one biogas unit. **Generate power** consumes one biogas unit for three local energy units, with no DPC grid credit. These are game recipes, not real sanitation, nutrient, mass/volume or energy certifications.

## Current Garden v0.4: recommended path

1. Install `DreamFarm_Garden_Link.lsl` beside upstream `DreamGarden_FarmManure.lsl` in the **same root**. Set Garden `ANIMALS=0` before first use so it does not independently generate synthetic manure.
2. Point Farm herd/pen manure exports at that root. Farm delivery reserves stock and uses durable receipts.
3. The bridge automatically forwards complete ten-unit loads through Garden's producer API. It hides its own touch/hover UI, leaving Garden's native collection-point menu. For debugging, `AUTO_LOAD=FALSE` enables manual **Load Garden 10**.
4. Use Garden's collection-point transfer menu to fill the Garden compost bin, then complete Garden composting and use its native finite fertilizer system.

One farm manure unit maps to one Garden RP unit. This bridge does not convert farm mature compost directly into current Garden fertilizer packets. Keep one bridge producer per collection point and preserve both scripts' saved state together.

Root-local **47130** sends `{v:1,op:"MANURE",seq,amount}` with a saved transaction UUID as the linked-message key. The bridge saves the manure debit, sequence and ID before sending. Garden returns **47131**, `{v:1,op:"ACK",seq}`, with the same key. Only the matching root-local acknowledgment clears the reservation. Lost replies retry the same saved sequence across resets; no timeout refund creates more manure.

Tests execute the unchanged current Garden collector fixture, blob **2f2cc6d789c40bd19c047b8e6c12b29f65d4ce77**, from Dream-Garden commit **d49dfc4b04b6674a0a2ebadffe6f16fd7317f3f4**. No upstream Garden files were modified.

## Legacy Garden v0.3 only

`DreamFarm_Garden_Applicator.lsl` supports existing installations of the older Botany `MANURE` tool interface. Its fixture is Botany blob **e51355c56537c5ca6133a35db66382d03862c05b**, header 0.3.0.

The legacy applicator receives mature farm compost, reserves two units and sends version 1 `USE/MANURE` on **-163847020**. It retries the same request within the old time window. Timeout/rejection holds the dose until **Resolve timeout → Confirm discard**, without refund. Basic Garden Plot is incompatible.

**Do not use the legacy applicator with current Garden v0.4.** Its old tool exchange does not represent the newer finite compost packets. Use the current manure producer bridge. Tests establish the pinned interfaces, not compatibility with arbitrary future Garden revisions.
