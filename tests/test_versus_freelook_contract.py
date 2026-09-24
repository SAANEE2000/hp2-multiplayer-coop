import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RECIPE = ROOT / "patches" / "versus-v16-free-look.json"
LAUNCHER = ROOT / "scripts" / "Launch-Multiplayer.ps1"


class VersusFreeLookContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe = json.loads(RECIPE.read_text(encoding="utf-8-sig"))
        cls.new_source = "\n".join(
            replacement["new"]
            for entry in cls.recipe["files"]
            for replacement in entry["replacements"]
        )

    def test_camera_state_is_local_and_has_no_replication_rpc(self):
        self.assertIn("var byte bVersusFreeLook;", self.new_source)
        self.assertIn("function bool ShouldCouplePawnRotationToCamera()", self.new_source)
        self.assertIn("return IsLocalViewportPlayer() && bVersusFreeLookActive;", self.new_source)
        self.assertNotIn("ServerVersusFreeLook", self.new_source)
        self.assertNotIn("ClientVersusFreeLook", self.new_source)

    def test_detached_aim_and_movement_use_frozen_pawn_state(self):
        self.assertIn("R = VersusFreeLookPawnRotation;", self.new_source)
        self.assertIn("AimRot = VersusFreeLookAimRotation;", self.new_source)
        self.assertIn("return VersusFreeLookPawnRotation;", self.new_source)
        self.assertIn("CamRot = GetScreenRelativeMovementRotation();", self.new_source)
        self.assertNotIn("bScreenRelativeMovement = False;", self.new_source)

    def test_stock_camera_orbits_its_attached_target(self):
        self.assertIn("Cam.bSyncPositionWithTarget = True;", self.new_source)
        self.assertIn("Cam.bSyncRotationWithTarget = False;", self.new_source)
        self.assertIn("StateStandardCam already rotates and positions the camera", self.new_source)
        self.assertIn("BaseCam(ViewTarget).rExtraRotation = rot(0,0,0);", self.new_source)
        self.assertIn("if (bVersusFreeLook == 0 && !bVersusFreeLookActive)", self.new_source)
        self.assertNotIn("static function UpdateFreeLookOrbit", self.new_source)

    def test_release_recenters_camera_without_rotating_pawn(self):
        self.assertIn("function EndVersusFreeLook()", self.new_source)
        self.assertIn("SetRotation(VersusFreeLookPawnRotation);", self.new_source)
        self.assertIn("Cam.InitPositionAndRotation(True);", self.new_source)

    def test_render_path_diagnostic_records_real_viewport_location(self):
        required = (
            "event PlayerCalcView",
            "ViewTargetEqualsCam=",
            "CamState=",
            "PlayerCalcView.CameraLocation=",
            "CameraLocationMinusCam=",
            "Cam.Location=",
            "Cam.LocationDelta=",
            "Cam.Rotation=",
            "Cam.rDestRotation=",
            "Cam.rCurrRotation=",
            "Cam.CamTarget.Location=",
            "Cam.CamTarget.Rotation=",
            "Cam.bSyncPositionWithTarget=",
            "Rotation=",
            "DesiredRotation=",
            "ViewRotation=",
            "bScreenRelativeMovement=",
        )
        for marker in required:
            with self.subTest(marker=marker):
                self.assertIn(marker, self.new_source)

    def test_death_and_setup_reset_local_state(self):
        self.assertIn('ResetVersusFreeLook("Death");', self.new_source)
        self.assertIn('ResetVersusFreeLook("Setup");', self.new_source)

    def test_console_handles_alt_without_manual_ini_edit(self):
        self.assertIn("function bool ApplyVersusFreeLookKey", self.new_source)
        self.assertIn("Key != IK_Alt && Key != IK_LAlt", self.new_source)
        self.assertIn("H.bVersusFreeLook = 1;", self.new_source)
        self.assertIn("H.bVersusFreeLook = 0;", self.new_source)
        launcher = LAUNCHER.read_text(encoding="utf-8")
        self.assertNotIn("Alt='FreeLook'", launcher)


if __name__ == "__main__":
    unittest.main()
