"""Exercise patch safety using temporary copies of the ignored v18 source.

Run with: python -m unittest discover -s tests -p test_patch_recipes.py -v
Set HP2_TEST_SOURCE_ROOT to a game/source root containing HGame/Classes if the
supplied v18/v18 tree lives elsewhere. No game source is embedded in this test.
"""

import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
APPLIER_PATH = REPO / "scripts" / "apply_patches.py"
SOURCE_ROOT = Path(os.environ.get("HP2_TEST_SOURCE_ROOT", REPO / "v18" / "v18"))
RECIPE_PATHS = tuple(sorted((REPO / "patches").glob("*.json")))
MARKER = ".hp2-development-copy.json"

_spec = importlib.util.spec_from_file_location("hp2_patch_applier", APPLIER_PATH)
applier = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(applier)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def tree_contents(root):
    """Detect changes to targets, backups, temporary files, and the marker."""
    return {
        str(path.relative_to(root)): path.read_bytes()
        for path in root.rglob("*")
        if path.is_file()
    }


def write_recipe(path, recipe):
    path.write_text(json.dumps(recipe, ensure_ascii=True), encoding="ascii")
    return path


def synthetic_entry(path, before=b"before\n", after=b"after\n"):
    return {
        "path": path,
        "source_sha256": digest(before),
        "result_sha256": digest(after),
        "replacements": [
            {"old": before.decode("latin-1"), "new": after.decode("latin-1")}
        ],
    }


class PatchRecipeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="hp2-patch-tests-")
        self.addCleanup(self.temporary.cleanup)
        self.temp = Path(self.temporary.name).resolve()

    def fixture(self, recipe_path):
        if not SOURCE_ROOT.is_dir():
            self.skipTest("Supplied v18 source missing; set HP2_TEST_SOURCE_ROOT")
        recipe = json.loads(recipe_path.read_text(encoding="utf-8-sig"))
        root = self.temp / recipe["name"]
        root.mkdir()
        (root / MARKER).write_text("{}", encoding="ascii")
        originals = {}
        for entry in recipe["files"]:
            source = SOURCE_ROOT / entry["path"]
            self.assertTrue(source.is_file(), f"Missing source fixture: {source}")
            original = source.read_bytes()
            self.assertEqual(digest(original), entry["source_sha256"], entry["path"])
            target = root / entry["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(original)
            originals[entry["path"]] = original
        return root, recipe, originals

    def apply(self, root, recipe_path):
        with contextlib.redirect_stdout(io.StringIO()):
            applier.apply_recipe(root, recipe_path)

    def test_expected_hashes_backups_and_idempotence(self):
        self.assertTrue(RECIPE_PATHS, "No patch recipes found")
        for recipe_path in RECIPE_PATHS:
            with self.subTest(recipe=recipe_path.name):
                root, recipe, originals = self.fixture(recipe_path)
                self.apply(root, recipe_path)
                for entry in recipe["files"]:
                    target = root / entry["path"]
                    self.assertEqual(digest(target.read_bytes()), entry["result_sha256"])
                    backup = root / ".patch-backups" / recipe["name"] / entry["path"]
                    self.assertEqual(backup.read_bytes(), originals[entry["path"]])
                first_result = tree_contents(root)
                timestamps = {
                    path: path.stat().st_mtime_ns
                    for path in root.rglob("*")
                    if path.is_file()
                }
                self.apply(root, recipe_path)
                self.assertEqual(tree_contents(root), first_result)
                self.assertEqual(
                    {path: path.stat().st_mtime_ns for path in timestamps}, timestamps
                )
                self.assertFalse(list(root.rglob("*.patch-tmp")))

    def test_late_input_tampering_rejects_entire_recipe_before_writes(self):
        for recipe_path in RECIPE_PATHS:
            with self.subTest(recipe=recipe_path.name):
                root, recipe, _ = self.fixture(recipe_path)
                # Single-file recipes still must reject tampering; multi-file
                # recipes also prove that earlier valid files remain untouched.
                self.assertGreater(len(recipe["files"]), 0)
                target = root / recipe["files"][-1]["path"]
                target.write_bytes(target.read_bytes() + b"\n// Temporary test tampering\n")
                before = tree_contents(root)
                with self.assertRaisesRegex(ValueError, "Source hash mismatch"):
                    self.apply(root, recipe_path)
                self.assertEqual(tree_contents(root), before)

    def test_bad_final_output_hash_rejects_entire_recipe_before_writes(self):
        for recipe_path in RECIPE_PATHS:
            with self.subTest(recipe=recipe_path.name):
                root, recipe, _ = self.fixture(recipe_path)
                recipe["files"][-1]["result_sha256"] = "0" * 64
                altered = write_recipe(self.temp / f"{recipe['name']}-bad-hash.json", recipe)
                before = tree_contents(root)
                with self.assertRaisesRegex(ValueError, "Output hash mismatch"):
                    self.apply(root, altered)
                self.assertEqual(tree_contents(root), before)

    def test_nonunique_anchor_rejects_entire_recipe_before_writes(self):
        for recipe_path in RECIPE_PATHS:
            with self.subTest(recipe=recipe_path.name):
                root, recipe, _ = self.fixture(recipe_path)
                # Empty anchors occur at every byte boundary; no source rewrite
                # should be permitted even after previous files were validated.
                recipe["files"][-1]["replacements"][0]["old"] = ""
                altered = write_recipe(self.temp / f"{recipe['name']}-bad-anchor.json", recipe)
                before = tree_contents(root)
                with self.assertRaisesRegex(ValueError, "Non-unique patch anchor"):
                    self.apply(root, altered)
                self.assertEqual(tree_contents(root), before)

    def test_target_path_escape_rejected_before_any_writes(self):
        root = self.temp / "game"
        root.mkdir()
        (root / MARKER).write_text("{}", encoding="ascii")
        (root / "inside.uc").write_bytes(b"before\n")
        outside = self.temp / "game-outside.uc"
        outside.write_bytes(b"before\n")
        for escaped_path in ("../game-outside.uc", str(outside)):
            with self.subTest(path=escaped_path):
                recipe = {
                    "name": "escape-test",
                    "files": [synthetic_entry("inside.uc"), synthetic_entry(escaped_path)],
                }
                recipe_path = write_recipe(self.temp / "escape.json", recipe)
                before = tree_contents(root)
                with self.assertRaisesRegex(ValueError, "escapes development tree"):
                    self.apply(root, recipe_path)
                self.assertEqual(tree_contents(root), before)
                self.assertEqual(outside.read_bytes(), b"before\n")

    def test_cli_rejects_unmarked_tree(self):
        root = self.temp / "unmarked"
        root.mkdir()
        (root / "source.uc").write_bytes(b"before\n")
        recipe_path = write_recipe(
            self.temp / "unmarked.json",
            {"name": "unmarked-test", "files": [synthetic_entry("source.uc")]},
        )
        before = tree_contents(root)
        result = subprocess.run(
            [sys.executable, str(APPLIER_PATH), "--work-root", str(root), str(recipe_path)],
            cwd=self.temp,
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("without the development-copy marker", result.stderr)
        self.assertEqual(tree_contents(root), before)


if __name__ == "__main__":
    unittest.main()
