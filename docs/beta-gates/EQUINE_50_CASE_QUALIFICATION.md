# Dream Farming — 50-case equine integration qualification

**Status:** 50 test definitions only; no simulator passes claimed. Execute on a test parcel before beta certification.

| # | Area | Scenario | Expected result | Evidence |
|---:|---|---|---|---|
| 1 | Identity | Owner same | Only same-owner Herd accepted | Pending |
| 2 | Identity | Owner changed | Previous owner records reset | Pending |
| 3 | Identity | Herd missing | No delivery attempted | Pending |
| 4 | Identity | Herd too far | Reject transfer beyond 8m | Pending |
| 5 | Identity | Herd near | Allow transfer within 8m | Pending |
| 6 | Identity | Cross-region | Reject absent target | Pending |
| 7 | Identity | Wrong target UUID | Reject wrong destination | Pending |
| 8 | Identity | Forged ACK sender | Reject response from another object | Pending |
| 9 | Identity | Forged ACK owner | Reject response from different owner | Pending |
| 10 | Identity | Unsolicited ACK | Ignore when no pending transfer | Pending |
| 11 | Water | No water | Reject request | Pending |
| 12 | Water | 9 water | Reject 10-unit request | Pending |
| 13 | Water | 10 water | Reserve exactly 10 | Pending |
| 14 | Water | 100 water | Reserve 10 and retain 90 after ACK | Pending |
| 15 | Water | Pending second request | Reject second concurrent transfer | Pending |
| 16 | Water | Lost LOAD | Retry same stream and sequence | Pending |
| 17 | Water | Lost ACK | Retry without double Herd credit | Pending |
| 18 | Water | Duplicate ACK | Stable debit only once | Pending |
| 19 | Water | Wrong quantity ACK | Reject mismatched amount | Pending |
| 20 | Water | Wrong material ACK | Reject FEED ACK for WATER | Pending |
| 21 | Feed | No hay | Reject request | Pending |
| 22 | Feed | 9 hay | Reject 10-unit request | Pending |
| 23 | Feed | 10 hay | Reserve FEED 10 | Pending |
| 24 | Feed | 100 hay | Debit 10 after valid ACK | Pending |
| 25 | Feed | Wrong WATER ACK | Reject WATER ACK for FEED | Pending |
| 26 | Feed | Feed retry | Reuse stream and sequence | Pending |
| 27 | Feed | Duplicate feed ACK | No duplicate debit | Pending |
| 28 | Feed | Herd FEED capacity full | Pending retained | Pending |
| 29 | Feed | Herd paused | Pending retained | Pending |
| 30 | Feed | Herd faulted | Pending retained | Pending |
| 31 | Persistence | Stable reset pending | Reload same stream/seq/kind/qty | Pending |
| 32 | Persistence | Stable reset idle | No phantom reservation | Pending |
| 33 | Persistence | Herd reset after credit | Persist receipt and reject duplicate | Pending |
| 34 | Persistence | Old schema migration | Default missing pendingKind to WATER | Pending |
| 35 | Persistence | Sequence exhaustion | Block rather than wrap | Pending |
| 36 | Persistence | Owner transfer pending | Reset state; flag economic reconciliation | Pending |
| 37 | Persistence | Herd switch pending | Block switch | Pending |
| 38 | Persistence | Herd switch idle | Clear stale assignments | Pending |
| 39 | Persistence | Copy object | Do not treat duplicated stock as authoritative | Pending |
| 40 | Persistence | Save failure | Do not claim committed delivery | Pending |
| 41 | Animal | Horse UUID valid | Allow living horse assignment | Pending |
| 42 | Animal | Donkey UUID valid | Allow living donkey assignment | Pending |
| 43 | Animal | Cattle UUID | Reject | Pending |
| 44 | Animal | Dead equine | Reject | Pending |
| 45 | Animal | Duplicate assignment | Reject | Pending |
| 46 | Animal | Stable full | Reject | Pending |
| 47 | Animal | Nonce mismatch | Reject | Pending |
| 48 | Animal | Verification timeout | Reject | Pending |
| 49 | Animal | Herd disappears | Pause monitoring | Pending |
| 50 | Manure | Muck out | No duplicate production; no unacknowledged compost credit | Pending |

## Exit criteria
All 50 cases must be executed with logs or screenshots, failures fixed and rerun. Verify both Mono compilation and local simulator behavior; source-level checks alone do not satisfy these gates. Use sandbox inventory, never live economy stock.
