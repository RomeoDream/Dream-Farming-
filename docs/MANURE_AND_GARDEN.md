# Manure and Dream-Garden

## Material cycle

Livestock consumes feed/water and generates fresh manure. Mucking out collects it and creates separate bedding-waste stock. Both can be sent to compost. Harvested dry crop residue supplies more browns.

A batch consumes **10 kg manure + 5 kg dry browns**. The alpha ingredient assumptions produce a C:N value around 23.3:1. Temperature, moisture, oxygen and recipe balance affect productive decomposition. Turning restores oxygen and wears the mixer. Watering consumes tank water; saturation slows activity.

A batch needs seven productive warm active days and seven suitable curing days. Productive days may take longer than calendar days. Mature yield is 55% of initial mass: **8.25 kg from a 15 kg batch**. These are compressed roleplay parameters, not measured processing times, fertilizer analyses or proof that real manure is sanitary.

Only mature stock is sent as `COMPOST`. Fields consume 2 kg per application, adding N/P/K and organic matter. Garden applicators also use 2 kg. Fresh `MANURE` is rejected by field fertilizer intake and Garden applicators.

## Verified interface

Inspected repository: `RomeoDream/Dream-Garden`, file `lsl/DreamGarden_Botany.lsl`, blob **e51355c56537c5ca6133a35db66382d03862c05b** (header 0.3.0). The test fixture is an unchanged snapshot of that file. No files in Dream-Garden were modified.

Botany accepts a `MANURE` tool described there as aged manure. The applicator uses that action for matured compost: version 1 JSON on channel `-163847020`, `op:USE`, `tool:MANURE`, owner actor, request UUID, original timestamp and exact target UUID.

Botany decides eligibility and effects. At this snapshot it adds 25 fertility points and 0.1 pH, with its own caps and threshold. The bridge cannot transmit N/P/K, moisture or quality because the existing protocol has no such fields. Those richer values remain a future interface extension.

The owner, applicator and target must be within Garden's 8 m limits. This alpha requires the same owner. The target must need fertilizer and be unpaused. The basic **DreamGarden_Plot.lsl is not compatible**; use the advanced Botany controller.

## Lost replies

Farm transfers have durable sequence receipts. Garden has a separate 10-second request window and bounded recent receipts. The applicator saves a debit and fixed request before sending, retries the same request within eight seconds, and clears the reserved dose only on a matching `ACK`.

Timeout or `ERR` holds the dose; there is no automatic refund. Inspect the plant, then use **Resolve timeout → Confirm discard** after expiration. This releases the hold without restoring compost. An uncertain dose can be lost, but cannot silently produce another free application through automatic refunds. A future Garden receipt-query API can improve recovery.

## Model inspiration

Game parameters are informed by the interacting C:N, moisture, oxygen and temperature factors described by university extension sources; they are not prescribed real-world recipes.

- [University of Minnesota: aged manure is not composted manure](https://blog-crop-news.extension.umn.edu/2022/02/aged-manure-is-not-composted-manure.html)
- [Cornell Composting: compost chemistry](https://www.compost.css.cornell.edu/chemistry.html)
- [University of Minnesota: manure sampling and nutrient analysis](https://extension.umn.edu/agriculture/animals-and-livestock/livestock-operations/manure-sampling-and-nutrient-analysis)
