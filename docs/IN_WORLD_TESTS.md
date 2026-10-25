# In-world acceptance checklist — not yet executed

Record viewer/server version, Mono compile result, free memory, elapsed times and screenshots. Run on test objects before using valuable farm content. A passing local Python/Lummao suite is not a substitute for this checklist.

| Test | Expected result | Result |
| --- | --- | --- |
| Compile all five scripts as Mono | No compiler errors; controllers show initial state | Pending |
| Settings → Diagnostics in each controller | Record actual free memory; leave comfortable headroom throughout later tests | Pending |
| Every menu/textbox on desktop and tablet viewer | Labels readable, buttons available, UUID entry works | Pending |
| Stranger touch and spoofed dialog reply | No state change | Pending |
| Walk beyond 8 m after opening dialog | Old reply ignored | Pending |
| Plow then plant each crop | Tillage required; seed/diesel debit once; stage 1 | Pending |
| Maintained growth in normal and demo | Progress, resource use and stage changes; no stack/heap errors | Pending |
| Drought, flood, frost, bad pH, weeds | Slower growth and appropriate damage; dead crop cannot harvest | Pending |
| Greenhouse power and water exhaustion | Conditioning/irrigation stops using exhausted supplies; never negative | Pending |
| Harvest, repeat click, reset | Exactly one credit; stock and empty field survive reset | Pending |
| Storage use and spoilage | Correct local debit and time-based spoilage | Pending |
| Pen feed/water/manure over one farm day | Supplies fall, manure rises, no negative balances | Pending |
| Muck out and export manure/bedding | Cleanliness rises; stock reserved once and credited once at compost | Pending |
| Stop receiver script before delivery | Sender retains pending load; enabling receiver eventually confirms once | Pending |
| Stop sender after receipt but before ACK | After reset, retransmission is deduplicated | Pending |
| Move receiver outside 8 m while pending | No unauthorized credit; delivery resumes when returned | Pending |
| Full/corrupt Linkset Data on disposable copy | No successful-action claim, no destructive overwrite | Pending |
| Managed compost through active and cure stages | Fresh stock consumed; mature yield appears once, only after cure | Pending |
| Immature pile Send compost | No transfer or garden credit | Pending |
| Compost → field | 2 kg credited; Soil care → Compost consumes and improves soil | Pending |
| Compost → Garden applicator → Botany | Fertility rises once; one 2 kg dose consumed; ACK clears hold | Pending |
| Garden rejects/timeout | No auto-refund; explicit discard resolves hold without restoring stock | Pending |
| Take/re-rez normal saved object with no pending loads | State survives; capped catch-up is understandable | Pending |
| Owner transfer/species change | Existing record preserved and locked | Pending |
| Optional field visuals | Only named stage children change; other build parts untouched | Pending |
| 20–50 objects under normal simulator load | Record script time, event delay, memory and dropped deliveries | Pending |

Do not certify cross-region operation, transferable goods, anti-copy integrity, server persistence, real payments or drivable machinery from these tests; those features are outside 0.1.0.
