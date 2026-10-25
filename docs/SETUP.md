# In-world setup

## Separate test objects

Rez test prims on land where you may build and run scripts. Give them the same owner and keep transfer endpoints within 8 metres. Use fresh test objects for this alpha.

| Object | Script in root | Optional setup |
| --- | --- | --- |
| Field | `lsl/DreamFarm_Field.lsl` | Add `DreamFarm_Visuals.lsl`; name crop-stage children `DF:Stage:0` through `DF:Stage:5` |
| Livestock pen | `lsl/DreamFarm_Livestock.lsl` | Set `SPECIES` before first use: `Cattle`, `Chicken`, `Sheep` or `Pig` |
| Compost pile | `lsl/DreamFarm_Compost.lsl` | One active batch per pile |
| Garden applicator | `lsl/DreamFarm_Garden_Applicator.lsl` | Keep near the Garden plant and owner during application |
| Garden plant | Existing `DreamGarden_Botany.lsl` | Do not add a farming controller to this linkset |

Paste each complete `lsl/` file into a **Mono** LSL script and compile. Never combine multiple farming controllers in one linkset. The visual script belongs beside the field controller in the root, not a child. Simple prims work without meshes.

Ordinary script reset preserves saved state. Changing a pen's species after initialization locks the existing record. Use a fresh pen for a different species. Owner transfers lock state rather than silently reassigning stock. Do not erase data to repair a pending delivery.

## Field controls

Stand within 8 m, touch the field, choose **Plow → Plant → crop**. Equipment consumes diesel and gains wear. **Soil care** offers water, fertilizer, delivered mature compost, lime, weeding and pest treatment. Dryness, waterlogging, frost, excessive fertility and neglect can damage crops.

**Utilities** offers greenhouse shelter, automatic irrigation, powered climate conditioning, equipment service, explicit sandbox restocks and storage. These are simulation controls; no building is rezzed and no external utility is connected.

At stage 4 choose **Harvest**. Crop removal, produce, seeds and residue save together. Stages: 0 bare, 1 seed, 2 sprout, 3 growing, 4 mature, 5 dead. **Clear crop** requires confirmation. **Storage** reports quantities; choosing a crop consumes 1 kg for roleplay. It does not sell or deliver inventory objects.

Visual meshes must be built separately. Only children named exactly `DF:Stage:0` ... `DF:Stage:5` change alpha. Other children remain untouched. The alpha uses the same stage meshes for all crops.

## Livestock controls

A pen represents an adult female/cohort with finite feed, water and bedding. **Feed 100**, **Water 200** and **Bedding 20** record roleplay deliveries without money charges. **Muck out** collects manure and consumes 2 kg bedding, storing the resulting used bedding separately.

**Breed** starts roleplay breeding service if health and stress permit it. Offspring are counts, not rezzed/growing animal objects. Milk requires a lactation window; chickens produce eggs, sheep wool and pigs offspring only. **Collect produce** removes whole produce units for roleplay. Milk and eggs spoil in the pen. Dead animals cannot be revived by Treat.

## Material destinations

Copy the destination **root object's UUID** with your viewer's object inspection/UUID command. On the source choose **Settings → Destination** and paste it. A name or inventory asset UUID will not work.

| Source | Destination | Command |
| --- | --- | --- |
| Pen | Compost pile | Send manure (10 kg), Send bedding (2 kg) |
| Field | Compost pile | Soil care → Send residue (10 kg) |
| Compost pile | Field or Garden applicator | Send compost (2 kg) |
| Garden applicator | Garden Botany plant | Apply compost (2 kg) |

The source debits and saves a load before sending. Keep both ends rezzed and running until confirmed. Lost replies cause the same saved load to retry. A new load cannot start while one is pending. Receivers keep up to **8 sender streams**, never evicting receipt history. Use additional piles rather than clearing receipts or copying objects containing live stock.

## Time

- Normal: one real hour = one farm day. Each new field starts its own 120-day temperate year in spring; fields are not globally synchronized.
- Demo x60: one real minute = one farm day. Damage is accelerated too.
- Simulation slices: 150 real seconds normally, 5 seconds in demo. Each timer event processes at most eight slices.
- The normal timer is 15 seconds. The applicator temporarily uses two seconds during Garden delivery.
- Offline catch-up retains at most 24 real hours. Excess time freezes and is recorded at state index 7. Remaining work catches up over later events; controls wait until caught up.
- Pause settles existing complete slices; paused time is not simulated on resume.
- A speed change settles complete slices at the old rate and resets the small partial remainder. Settings are owner sandbox controls, not an anti-cheat boundary.

## Recovery

A failed save locks actions and retains the previous durable record. Repair exhausted Linkset Data space, then reset. Invalid records are preserved. If a destination is deleted or its root UUID changes during a pending transfer, there is no automatic refund: restore the receiver if possible or use an audited recovery/migration later.

Do not relink active controller roots with pending transfers. Copying objects copies their stock and stream identities; this local alpha is cooperative roleplay, not a tamper-proof economy.
