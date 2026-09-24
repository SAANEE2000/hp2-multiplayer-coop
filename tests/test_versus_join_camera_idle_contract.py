import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RECIPE = ROOT / "patches" / "versus-v16-join-camera-idle-fix.json"


class VersusJoinCameraIdleContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        recipe = json.loads(RECIPE.read_text(encoding="utf-8-sig"))
        cls.by_path = {
            entry["path"]: "\n".join(
                replacement["new"] for replacement in entry["replacements"]
            )
            for entry in recipe["files"]
        }

    def test_countdown_restart_preserves_existing_view_basis(self):
        game = self.by_path["HGame/Classes/HPVersusGame.uc"]
        self.assertIn("bPreserveLiveCamera = VersusPhase == 'Countdown';", game)
        self.assertIn("SavedRotation = H.Rotation;", game)
        self.assertIn("SavedDesiredRotation = H.DesiredRotation;", game)
        self.assertIn("SavedViewRotation = H.ViewRotation;", game)
        self.assertIn("H.ClientVersusRespawn(bPreserveLiveCamera);", game)

    def test_client_avoids_hard_camera_reinit_only_for_live_join(self):
        harry = self.by_path["HGame/Classes/HPVersusHarry.uc"]
        self.assertIn(
            "function ClientVersusRespawn(optional bool bPreserveLiveCamera)", harry
        )
        self.assertIn("if (bPreserveVersusCameraOnSetup)", harry)
        self.assertIn("static.ApplyStandardCam(self);", harry)
        self.assertIn("static.ForceStandardCam(self);", harry)
        self.assertIn("bPreserveVersusCameraOnSetup = False;", harry)

    def test_linked_roster_uses_common_idle_instead_of_random_variants(self):
        harry = self.by_path["HGame/Classes/HPVersusHarry.uc"]
        self.assertIn("function bool UsesStableVersusIdle()", harry)
        self.assertIn("function name GetCurrIdleAnimName()", harry)
        self.assertIn("function name GetCurrFidgetAnimName()", harry)
        self.assertGreaterEqual(
            harry.count("return HarryAnims[HarryAnimSet].Idle;"), 2
        )
        self.assertIn("LoopAnim(CurrIdleAnimName, 0.8, 0.15", harry)
        self.assertNotIn('"idle_1"', harry)


if __name__ == "__main__":
    unittest.main()
