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

    def test_water_delivery_uses_durable_receipts(self):
        for fragment in (
            'llLinksetDataWrite(PREFIX+"pendingWater"',
            'llLinksetDataWrite(PREFIX+"transferStream"',
            'llLinksetDataWrite(PREFIX+"transferSeq"',
            '"op","LOAD"',
            '"kind","WATER"',
            'llJsonGetValue(message,["op"])!="ACK"',
            'water-=pendingWater;pendingWater=0;save();',
            'if(pendingWater>0)',
        ):
            self.assertIn(fragment, STABLE)

    def test_dialog_limits(self):
        dialogs = re.findall(r'llDialog\(who,[^\n]*\[([^\]]+)\],CHANNEL\)', STABLE)
        self.assertTrue(dialogs)
        for buttons in dialogs:
            self.assertLessEqual(len(re.findall(r'"[^"]+"', buttons)), 12)


if __name__ == "__main__":
    unittest.main()
