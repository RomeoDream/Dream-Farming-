# In-world acceptance checklist — not yet executed

Record Second Life viewer/server version, Mono compile result, free memory, script time, elapsed times and screenshots on test objects. Lummao tests execute the source but do not measure simulator physics, memory, rendering, throttles or real service availability.

| Test | Expected result | Result |
| --- | --- | --- |
| Compile all fourteen generated scripts as Mono | No errors; valid default state | Pending |
| Diagnostics at maximum herd, stock, ledger and receipt occupancy | Record actual free memory; no stack/heap collisions during updates | Pending |
| Every menu, material page and Unicode textbox | Buttons fit, text fits viewer byte limits, correct actor and channel | Pending |
| Stranger/group/assigned-worker access | Only configured care/job actions; no unauthorized restock, transfer or invoice | Pending |
| Open dialog, then leave 8 m range | Reply ignored | Pending |
| Field v0.1 upgrade with pending transfer | Stock, outbox ID and receipts survive migration; delivery completes once | Pending |
| All six crops, soil types and seasonal gates | Resource-dependent growth/harvest; winter restrictions where enabled | Pending |
| Drought, flood, frost, poor pH, pests and neglect | Slower growth/damage; dead crop never harvests | Pending |
| Harvest twice, reset, export | One harvest credit; finite exported stock | Pending |
| Tractor seat/control/engine | Owner permissions; no movement before valid fuel lease | Pending |
| Out of fuel, permission loss, driver stop, unseat, reset and region change | Motion stops; reset requires manual engine restart | Pending |
| Physical slopes, collisions and simulator lag | Stable hull; speed/range gates understandable; no runaway motor | Pending |
| Plow/sow/weed/harvest all 64 cells | Actual movement counts each cell once; final operation occurs once | Pending |
| Leave field, drive too fast, stop or switch unfinished job | Invalid work rejected; explicit coverage reset available | Pending |
| Field seed empty, season closed or harvest storage full at final cell | Final operation and final cell remain unapplied | Pending |
| Individual herd feed/water and waste | Finite shared supplies, milk/eggs/wool/manure quantities, no negative stock | Pending |
| Mate/birth/reset/grow young | One litter, parent identities retained, young mature, full pens hold births | Pending |
| Related/immature/stressed breeding and dead-animal treatment | Rejected; no resurrection or duplicate births | Pending |
| Muck out → manure/bedding → compost | One source debit/receiver credit; fresh waste is not mature fertilizer | Pending |
| All three compost recipes through active/cure phases | Correct ingredients/yields; management required; one completion | Pending |
| Each processor recipe through reset and resource outage | Inputs consumed once; output reserved; progress stalls without utilities | Pending |
| Slurry → digestate/biogas → local energy | Both outputs appear once; generator consumes actual biogas | Pending |
| Full storage/batch reservations and refrigeration outage | Capacity respected; spoilage changes when power is unavailable | Pending |
| Pump/valve/head/leak/repair | Delivery consumes finite water/power; spill recorded; repairs use parts | Pending |
| Stop receiver / drop ACK / move beyond 8 m | One persistent load; retry credits once after recovery, no timeout refund | Pending |
| Fill eight receipt streams | Ninth is held; prior receipt records are never evicted | Pending |
| Fail writes / corrupt disposable state | Original record preserved, no successful action or motion authorization | Pending |
| Current Garden bridge with ANIMALS=0 | Farm manure arrives once in native collection point; native compost/fertilizer workflow works | Pending |
| Current Garden bridge lost linked ACK and reset | Same saved sequence retries; no extra manure | Pending |
| Legacy Garden v0.3 applicator only | One mature dose; unknown outcome holds; explicit discard gives no refund | Pending |
| Board register/poll/stale/foreign source | Only registered owner nodes update; stale reading visible after 60 s | Pending |
| Office assignment and completion | Authorized manual status changes; retained jobs and no duplicate completion count | Pending |
| Bank adapter approval, real invoice, partial/full payment, reset | Same immutable bill; only matching full PAID counted once | Pending |
| TXAGO real HTTP/engine refusal/outage | No fuel bypass or local fallback; STOP/stale status halts motion | Pending |
| DPC real panel/cord/appliance/outage/restore | Correct demands; no local energy fallback or retroactive offline power | Pending |
| Re-rez / owner change / species/config change | Supported resets retain state; incompatible bindings lock for reconciliation | Pending |
| Optional field stage meshes | Only named DF:Stage:0..5 children change; other build parts untouched | Pending |
| 20–50 connected objects | Record memory, event delays, script time and throughput; tune limits from evidence | Pending |

Public cross-owner sales, secure transferable stock, authoritative servers, towing/hitch physics and finished art are outside this release. These tests do not certify those capabilities.
