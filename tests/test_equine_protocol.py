"""Static safety invariants for the experimental equine stable.

These checks are not an LSL compiler or a substitute for in-world testing.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STABLE = (ROOT / "experimental/DreamFarm_EquineStable.lsl").read_text()
HERD = (ROOT / "src/DreamFarm_Herd.lsl").read_text()


class EquineProtocolTests(unittest.TestCase):
    def test_herd_owns_welfare_and_manure(self):
        self.assertIn("stableManureEnabled=FALSE", STABLE)
        self.assertIn("careAccountingMode=0", STABLE)
        self.assertNotIn("manure=clampInt(manure+n", STABLE)
        self.assertNotIn("hay-=hayNeeded", STABLE)
        self.assertNotIn("water-=waterNeeded", STABLE)

    def test_stable_rejects_wrong_herd_and_stale_responses(self):
        for fragment in (
            "id!=herdRoot",
            "llGetOwnerKey(id)!=llGetOwner()",
            "!validHerdRoot(herdRoot)",
            "llGetUnixTime()>pendingUntil",
            '["nonce"])!=pendingNonce',
            '["animal"])!=pendingAnimal',
        ):
            self.assertIn(fragment, STABLE)

    def test_switching_herd_invalidates_old_assignments(self):
        self.assertIn("if(nextHerd!=herdRoot){assigned=[];", STABLE)
        self.assertIn('careEnabled=FALSE;', STABLE)

    def test_legacy_unverified_assignments_are_cleared(self):
        self.assertIn('llLinksetDataRead(PREFIX+"verifiedAssignments")!="1"', STABLE)
        self.assertIn('llLinksetDataWrite(PREFIX+"verifiedAssignments","1")', STABLE)

    def test_herd_verifies_species_and_life(self):
        self.assertIn("(sp==4 || sp==5)", HERD)
        self.assertIn("llList2Integer(a,15)", HERD)
        self.assertIn("llGetOwnerKey(who)!=llGetOwner()", HERD)

    def test_feed_and_water_deliveries_use_durable_receipts(self):
        for fragment in (
            'llLinksetDataWrite(PREFIX+"pendingWater"',
            'llLinksetDataWrite(PREFIX+"transferStream"',
            'llLinksetDataWrite(PREFIX+"transferSeq"',
            '"op","LOAD"',
            '"kind",pendingKind',
            'llLinksetDataWrite(PREFIX+"pendingKind"',
            'if(message=="Send feed")kind="FEED"',
            'llJsonGetValue(message,["op"])!="ACK"',
            'if(pendingKind=="WATER")water-=pendingWater;',
            'else hay-=pendingWater;',
            'if(pendingWater>0)',
        ):
            self.assertIn(fragment, STABLE)

    def test_ack_payload_is_strictly_validated(self):
        self.assertIn('llJsonValueType(message,[])!=JSON_OBJECT', STABLE)
        self.assertIn('llJsonValueType(message,["seq"])!=JSON_NUMBER', STABLE)
        self.assertIn('llJsonValueType(message,["qty"])!=JSON_NUMBER', STABLE)
        self.assertIn('(float)llJsonGetValue(message,["seq"])!=(float)transferSeq', STABLE)
        self.assertIn('(float)llJsonGetValue(message,["qty"])!=(float)pendingWater', STABLE)

    def test_transfer_range_is_enforced_on_retries(self):
        self.assertIn('integer transferInRange()', STABLE)
        self.assertIn('<=8.0', STABLE)
        self.assertIn('if(pendingWater>0 && transferInRange()', STABLE)

    def test_pending_delivery_retry_audit_is_persistent(self):
        for fragment in (
            'llLinksetDataWrite(PREFIX+"pendingStarted"',
            'llLinksetDataWrite(PREFIX+"transferAttempts"',
            'pendingStarted=llGetUnixTime()',
            'transferAttempts+=1',
            'pendingStarted=0;transferAttempts=0;save();',
        ):
            self.assertIn(fragment, STABLE)

    def test_owner_transfer_clears_state(self):
        self.assertIn('llLinksetDataWrite(PREFIX+"owner"', STABLE)
        self.assertIn('savedOwner!=(string)llGetOwner()', STABLE)
        self.assertIn('pendingWater=0;pendingKind="WATER";transferSeq=0;', STABLE)
        self.assertIn('herdRoot=NULL_KEY', STABLE)

    def test_status_exposes_pending_transfer_diagnostics(self):
        self.assertIn(' | Pending "+pendingKind+', STABLE)
        self.assertIn(' | Retry "+(string)transferAttempts+', STABLE)
        self.assertIn('pendingWater>0?llGetUnixTime()-pendingStarted:0', STABLE)

    def test_dialog_limits(self):
        dialogs = re.findall(r'llDialog\(who,[^\n]*\[([^\]]+)\],CHANNEL\)', STABLE)
        self.assertEqual(len(dialogs), 2, "Both main and settings dialogs must be checked")
        for buttons in dialogs:
            self.assertLessEqual(len(re.findall(r'"[^"]+"', buttons)), 12)


if __name__ == "__main__":
    unittest.main()
