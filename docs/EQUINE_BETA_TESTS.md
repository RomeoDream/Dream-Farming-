# Equine beta acceptance tests — horse/donkey Herd + Stable

Status: **test plan, not test results**. Neither LSL compilation nor Second Life simulator behavior has been verified by this document.

## Preflight
- Use two separate same-owner root objects in the same region: `lsl/DreamFarm_Herd.lsl` and `experimental/DreamFarm_EquineStable.lsl`.
- Save scripts as Mono. Record compiler errors, free memory, owner UUID, region, and script versions.
- Keep all tests on a sandbox parcel where building and scripts are permitted. Do not place any real economic inventory at risk.
- Herd is authoritative for feed, water, animal welfare and manure. Stable monitoring must not debit feed/water or mint manure.

## Acceptance matrix

| ID | Procedure | Expected outcome |
| --- | --- | --- |
| E01 | Touch Herd → Manage → Equines | Equines menu opens without exceeding 12 dialog buttons |
| E02 | Add Mare and Stallion | Two distinct IDs, correct sex and Horse species |
| E03 | Add Jenny and Jack | Two distinct IDs, correct sex and Donkey species |
| E04 | Breed eligible unrelated Mare/Stallion | Pregnancy due date set, eventual foal, parent IDs retained |
| E05 | Breed eligible unrelated Jenny/Jack | Pregnancy due date set, eventual foal, parent IDs retained |
| E06 | Breed cross-species Horse/Donkey | Rejected under current same-species rule; mule/hinny breeding is not implemented |
| E07 | Set Herd root UUID on Stable | Same-owner object within 96m accepted |
| E08 | Enter unrelated/remote/nonexistent Herd UUID | Rejected or warned; no verified stall assignment |
| E09 | Assign living Horse UUID to Stable | Stable sends request; Herd responds; assignment saved once |
| E10 | Assign living Donkey UUID | Verified assignment saved |
| E11 | Assign cattle/chicken/sheep/pig UUID | Rejected |
| E12 | Assign nonexistent or dead animal UUID | Rejected |
| E13 | Assign duplicate UUID | Rejected |
| E14 | Fill stable then assign another animal | Rejected at stall capacity |
| E15 | Reset Stable script | Assignments and local supplies survive |
| E16 | Remove Herd or block communications | Assignment times out without adding an unverified UUID |
| E17 | Enable stable care monitoring | Herd welfare remains authoritative; no stable feed/water deduction |
| E18 | Muck out | Existing local manure moves to collected stock, not deleted or duplicated |
| E19 | Duplicate a Stable object | Do not treat copied local stock as authoritative tradable inventory |
| E20 | Verify compost transfer | **Not implemented** — must remain blocked until receipt-based transfer is integrated |

## Known limitations
- Stable verifies animal UUID at assignment time only; death, movement or rehoming after assignment does not automatically release a stall.
- The stable is not yet a secure server-backed inventory source, and cannot safely send its collected manure to compost.
- No riding, cart physics, tack or mesh animations are included.
- Existing animal production is local to Herd; Cloudflare livestock metrics require a separate synchronization adapter.
- Do not mark this milestone beta-ready until all applicable acceptance tests pass in Second Life and any failing tests have fixes committed.
