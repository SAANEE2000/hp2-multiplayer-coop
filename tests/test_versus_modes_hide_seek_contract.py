import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLASSES = ROOT / "mod" / "versus-v16" / "HGame" / "Classes"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_map_catalog_is_central_and_mode_filtered():
    catalog = json.loads(read(ROOT / "config" / "versus-maps.json"))
    assert catalog["schemaVersion"] == 1
    maps = catalog["maps"]
    assert len({entry["MapId"] for entry in maps}) == len(maps)
    assert len({entry["PackageName"].casefold() for entry in maps}) == len(maps)
    for entry in maps:
        assert set(entry) == {
            "MapId", "DisplayName", "PackageName", "SupportsFFA",
            "SupportsHideSeek", "MinPlayers", "MaxPlayers",
        }
        assert 2 <= entry["MinPlayers"] <= entry["MaxPlayers"] <= 8
    startup = next(entry for entry in maps if entry["MapId"] == "StartupArena")
    hide_seek = next(entry for entry in maps if entry["MapId"] == "HideSeekLab")
    assert startup["SupportsFFA"] and not startup["SupportsHideSeek"]
    assert hide_seek["SupportsHideSeek"] and not hide_seek["SupportsFFA"]


def test_hide_seek_reuses_versus_game_and_has_explicit_state_machine():
    game = read(CLASSES / "HPHideSeekGame.uc")
    assert "class HPHideSeekGame extends HPVersusGame;" in game
    for phase in (
        "WaitingForPlayers", "SelectHunter", "HidePhase", "HuntPhase",
        "RoundOver", "NextRound",
    ):
        assert f"'{phase}'" in game
    assert "Super.Login" not in game
    assert "DefaultPlayerClass=Class'HGame.HPVersusHarry'" in game
    assert "GameReplicationInfoClass=Class'HGame.HPHideSeekGRI'" in game
    assert "PreviousHunterSlot" in game
    assert "HandleVersusRictusempraModeHit" in game
    assert "NotifyHiderCaught" in game
    assert "VersusKilledBy" not in game


def test_hide_seek_replication_and_disguise_are_bounded():
    gri = read(CLASSES / "HPHideSeekGRI.uc")
    game = read(CLASSES / "HPHideSeekGame.uc")
    catalog = read(CLASSES / "HPHideSeekDisguiseCatalog.uc")
    assert "class HPHideSeekGRI extends HPVersusGRI;" in gri
    assert all(name in gri for name in ("HideSeekPhase", "HidersLeft", "HunterSlot"))
    assert "DISGUISE_COUNT = 6" in catalog
    assert catalog.count("return SkeletalMesh'") == 6
    assert "CanVersusDisguise" in game
    assert "ServerDisguiseTrace" not in game
    assert "SetCollisionSize(Hit." not in game


def test_common_pawn_contains_only_mode_bridge_and_authority_validation():
    recipe = json.loads(read(ROOT / "patches" / "versus-v16-hide-seek.json"))
    entries = {entry["path"]: entry for entry in recipe["files"]}
    assert set(entries) == {
        "HGame/Classes/HPVersusGame.uc",
        "HGame/Classes/HPVersusHarry.uc",
    }
    harry = entries["HGame/Classes/HPVersusHarry.uc"]["replacements"][0]["new"]
    versus = entries["HGame/Classes/HPVersusGame.uc"]["replacements"][0]["new"]
    for field in (
        "HideSeekRole", "bHideSeekCaught", "bVersusModeMovementLocked",
        "bVersusModeCastingLocked", "HideSeekDisguiseIndex",
    ):
        assert field in harry
    assert "ServerCycleHideSeekDisguise" in harry
    assert "IsVersusCastAllowed(self, SelectedVersusSpell)" in harry
    assert "HandleVersusRictusempraModeHit" in harry
    assert "if (HPHideSeekGame" not in harry
    for hook in (
        "IsVersusCastAllowed", "IsVersusDamageAllowed",
        "HandleVersusRictusempraModeHit", "CanVersusDisguise",
    ):
        assert re.search(rf"function bool {hook}\b", versus)


def test_launcher_and_menu_expose_both_modes_and_map_catalog():
    launch = read(ROOT / "scripts" / "Launch-Multiplayer.ps1")
    start = read(ROOT / "scripts" / "Start-MenuTest.ps1")
    menu = read(ROOT / "scripts" / "Show-MenuTest.ps1")
    prepare = read(ROOT / "scripts" / "Prepare-VersusInteractionArena.ps1")
    assert "ValidateSet('Coop','Versus','HideSeek')" in launch
    assert "config\\versus-maps.json" in launch
    assert "SupportsHideSeek" in launch and "SupportsFFA" in launch
    assert "HGame.HPHideSeekGame" in launch
    assert "?HideTime=$HideTime`?HuntTime=$HuntTime" in launch
    assert "NumPad0='CycleVersusDisguise'" in launch
    assert "HideSeekHost" in start and "HideSeekJoin" in start
    assert "Show-VersusModeSelect" in menu
    assert "Каждый за себя" in menu and "Прятки" in menu
    assert "Add-MenuMapChoice" in menu
    assert "HPV_HideSeek.unr" in prepare


def test_fixture_uses_round_markers_without_replacing_login_starts():
    arena = read(CLASSES / "HPHideSeekArena.uc")
    hider = read(CLASSES / "HPHideSeekHiderStart.uc")
    wait = read(CLASSES / "HPHideSeekHunterWaitStart.uc")
    seek = read(CLASSES / "HPHideSeekHunterSeekStart.uc")
    assert "HPHideSeekHunterWaitStart" in arena
    assert "HPHideSeekHunterSeekStart" in arena
    assert "HPHideSeekHiderStart HiderStarts[8]" in arena
    assert "HPVersusStart" not in arena
    for marker in (hider, wait, seek):
        assert "extends NavigationPoint" in marker
        assert "bSinglePlayerStart" not in marker
        assert "bCoopStart" not in marker


def load_tests(loader, tests, pattern):
    suite = unittest.TestSuite()
    for case in (
        test_map_catalog_is_central_and_mode_filtered,
        test_hide_seek_reuses_versus_game_and_has_explicit_state_machine,
        test_hide_seek_replication_and_disguise_are_bounded,
        test_common_pawn_contains_only_mode_bridge_and_authority_validation,
        test_launcher_and_menu_expose_both_modes_and_map_catalog,
        test_fixture_uses_round_markers_without_replacing_login_starts,
    ):
        suite.addTest(unittest.FunctionTestCase(case))
    return suite
