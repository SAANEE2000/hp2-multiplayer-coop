import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PATCHES = ROOT / "patches"
LAUNCHER = ROOT / "scripts" / "Launch-Multiplayer.ps1"
HUD = ROOT / "mod" / "versus-v16" / "HGame" / "Classes" / "HPVersusHUD.uc"
MOD_CLASSES = ROOT / "mod" / "versus-v16" / "HGame" / "Classes"
ARENA_SCRIPT = ROOT / "scripts" / "Prepare-VersusInteractionArena.ps1"


class VersusSpellTestContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.launcher = LAUNCHER.read_text(encoding="utf-8")
        cls.hud = HUD.read_text(encoding="utf-8")
        cls.arena_script = ARENA_SCRIPT.read_text(encoding="utf-8")
        recipes = []
        for path in sorted(PATCHES.glob("versus-v16-*.json")):
            recipes.append(json.loads(path.read_text(encoding="utf-8-sig")))
        cls.patch_text = "\n".join(
            replacement["new"]
            for recipe in recipes
            for entry in recipe["files"]
            for replacement in entry["replacements"]
        )

    def test_v16_launcher_uses_real_numpad_bind_names_only(self):
        branch = re.search(
            r"elseif \(Test-Path .*?\.hp2-versus-v16-source\.json.*?\) \{"
            r"(?P<body>.*?)\n\} else \{",
            self.launcher,
            re.DOTALL,
        )
        self.assertIsNotNone(branch)
        body = branch.group("body")
        for number in range(1, 7):
            self.assertIn(
                f"NumPad{number}='VersusSpell{number}'", body
            )
            self.assertNotIn(f"'{number}'='VersusSpell{number}'", body)

    def test_selection_is_local_preview_then_server_validated(self):
        self.assertIn("if (NewSpellSlot > 5)", self.patch_text)
        self.assertIn("SelectedVersusSpell = NewSpellSlot;", self.patch_text)
        self.assertIn("W.ApplyVersusVisualSpell(NewSpellSlot);", self.patch_text)
        self.assertIn("ServerSelectVersusSpell(NewSpellSlot);", self.patch_text)

    def test_all_six_slots_and_wand_whitelist_are_present(self):
        classes = (
            "HPVersusSpell",
            "HPVersusMimblewimble",
            "HPVersusExpelliarmus",
            "HPVersusFlipendo",
            "HPVersusAlohomora",
            "HPVersusSpongify",
        )
        for slot, class_name in enumerate(classes):
            with self.subTest(slot=slot, class_name=class_name):
                self.assertIn(f"case {slot}:", self.patch_text)
                self.assertIn(f"Class'{class_name}'", self.patch_text)
        self.assertIn("SpellClass != Class'HPVersusAlohomora'", self.patch_text)
        self.assertIn("SpellClass != Class'HPVersusSpongify'", self.patch_text)

    def test_non_damage_world_spell_contracts_remain_stock_based(self):
        alohomora = (MOD_CLASSES / "HPVersusAlohomora.uc").read_text(encoding="utf-8")
        spongify = (MOD_CLASSES / "HPVersusSpongify.uc").read_text(encoding="utf-8")
        flipendo = (MOD_CLASSES / "HPVersusFlipendo.uc").read_text(encoding="utf-8")
        self.assertIn("return False;", alohomora)
        self.assertIn("HandleSpellAlohomora", alohomora)
        self.assertIn("return False;", spongify)
        self.assertIn("HandleSpellSpongify", spongify)
        self.assertIn("OnSpellHitHarry", flipendo)
        self.assertIn("HandleSpellFlipendo", flipendo)

    def test_hud_has_health_spell_icon_and_precise_cooldown(self):
        self.assertIn('"HP"', self.hud)
        self.assertIn('"SELECTED SPELL"', self.hud)
        self.assertIn('"READY"', self.hud)
        self.assertIn('"COOLDOWN " $ FormatVersusSeconds', self.hud)
        self.assertIn('"MUTED " $ FormatVersusSeconds', self.hud)
        self.assertIn('"SPEED x"', self.hud)
        self.assertIn("VersusSpellIcons[5]", self.hud)
        self.assertIn("HP2_Menu.Icons.HP2SpellRictusempraSelect", self.hud)
        self.assertIn("SpellShapes.SpellFX.SpongifyWet1", self.hud)
        self.assertIn("if (bVersusHUDTextureLoadAttempted)", self.hud)
        self.assertIn("bVersusHUDTextureLoadAttempted = True;", self.hud)
        self.assertNotIn("#exec TEXTURE IMPORT", self.hud)

    def test_interaction_map_is_isolated_and_uses_stock_actor_bases(self):
        self.assertIn("Maps\\startup.unr", self.arena_script)
        self.assertIn("Maps\\HPV_Interactions.unr", self.arena_script)
        self.assertIn("Interaction arena copy hash mismatch", self.arena_script)
        bases = {
            "HPVersusArenaLock.uc": "extends Padlock",
            "HPVersusArenaCauldron.uc": "extends BronzeCauldron",
            "HPVersusArenaFlipendoTrigger.uc": "extends spellTrigger",
            "HPVersusSpongifyPad.uc": "extends SpongifyPad",
            "HPVersusSpongifyTarget.uc": "extends SpongifyTarget",
        }
        for filename, declaration in bases.items():
            with self.subTest(filename=filename):
                source = (MOD_CLASSES / filename).read_text(encoding="utf-8")
                self.assertIn(declaration, source)


if __name__ == "__main__":
    unittest.main()
