"""Exercise patch safety using temporary copies of the supplied source bases.

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
import zipfile


REPO = Path(__file__).resolve().parents[1]
APPLIER_PATH = REPO / "scripts" / "apply_patches.py"
SOURCE_ROOT = Path(os.environ.get("HP2_TEST_SOURCE_ROOT", REPO / "v18" / "v18"))
RECIPE_PATHS = tuple(sorted((REPO / "patches").glob("*.json")))
V16_RECIPE_PATHS = tuple(p for p in RECIPE_PATHS if p.name.startswith("versus-v16-"))
LEGACY_RECIPE_PATHS = tuple(p for p in RECIPE_PATHS if p not in V16_RECIPE_PATHS)
V16_ARCHIVE = REPO / "HPVersus_v16_remote_bottom_align_20260905.zip"
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


def source_bytes(relative, v16=False):
    if v16:
        with zipfile.ZipFile(V16_ARCHIVE) as archive:
            source_path = Path(relative)
            try:
                nested = source_path.relative_to(Path("HGame") / "Classes")
            except ValueError:
                nested = Path(source_path.name)
            return archive.read("Classes/" + nested.as_posix())
    return (SOURCE_ROOT / relative).read_bytes()


def source_at_hash(relative, wanted_hash, v16=False):
    """Derive a dependent recipe's input without changing the supplied fixture."""
    data = source_bytes(relative, v16)
    seen = set()
    while digest(data) != wanted_hash:
        current = digest(data)
        if current in seen:
            raise AssertionError(f"Fixture recipe cycle: {relative}")
        seen.add(current)
        matches = []
        for path in (V16_RECIPE_PATHS if v16 else LEGACY_RECIPE_PATHS):
            recipe = json.loads(path.read_text(encoding="utf-8-sig"))
            matches.extend(entry for entry in recipe["files"]
                           if entry["path"] == relative and entry["source_sha256"] == current)
        if len(matches) != 1:
            raise AssertionError(f"Missing/ambiguous fixture predecessor: {relative}")
        entry = matches[0]
        for edit in entry["replacements"]:
            before, after = edit["old"].encode("latin-1"), edit["new"].encode("latin-1")
            if data.count(before) != 1:
                raise AssertionError(f"Nonunique fixture anchor: {relative}")
            data = data.replace(before, after, 1)
        if digest(data) != entry["result_sha256"]:
            raise AssertionError(f"Bad fixture output: {relative}")
    return data


class PatchRecipeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="hp2-patch-tests-")
        self.addCleanup(self.temporary.cleanup)
        self.temp = Path(self.temporary.name).resolve()

    def fixture(self, recipe_path):
        v16 = recipe_path in V16_RECIPE_PATHS
        if v16 and not V16_ARCHIVE.is_file():
            self.skipTest("Supplied v16 archive missing")
        if not v16 and not SOURCE_ROOT.is_dir():
            self.skipTest("Supplied v18 source missing; set HP2_TEST_SOURCE_ROOT")
        recipe = json.loads(recipe_path.read_text(encoding="utf-8-sig"))
        root = self.temp / recipe["name"]
        root.mkdir()
        (root / MARKER).write_text("{}", encoding="ascii")
        originals = {}
        for entry in recipe["files"]:
            original = source_at_hash(entry["path"], entry["source_sha256"], v16)
            self.assertEqual(digest(original), entry["source_sha256"], entry["path"])
            target = root / entry["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(original)
            originals[entry["path"]] = original
        return root, recipe, originals

    def apply(self, root, recipe_path):
        with contextlib.redirect_stdout(io.StringIO()):
            applier.apply_recipe(root, recipe_path)

    def apply_batch(self, root, recipe_paths):
        with contextlib.redirect_stdout(io.StringIO()):
            applier.apply_recipes(root, recipe_paths)

    def synthetic_root(self, content=b"before\n"):
        root = self.temp / "game"
        root.mkdir()
        (root / MARKER).write_text("{}", encoding="ascii")
        (root / "source.uc").write_bytes(content)
        return root

    def edge_recipe(self, name, before, after, relative="source.uc"):
        return write_recipe(self.temp / (name + ".json"),
                            {"name": name, "files": [synthetic_entry(relative, before, after)]})

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

    def test_all_real_recipes_clean_partial_and_repeated(self):
        for v16, recipe_paths in ((False, LEGACY_RECIPE_PATHS), (True, V16_RECIPE_PATHS)):
            if v16 and not V16_ARCHIVE.is_file():
                continue
            if not v16 and not SOURCE_ROOT.is_dir():
                continue
            recipes = [json.loads(p.read_text(encoding="utf-8-sig")) for p in recipe_paths]
            relatives = {e["path"] for r in recipes for e in r["files"]}
            for partial in (False, True):
                with self.subTest(v16=v16, partial=partial):
                    root = self.temp / ("v16-" if v16 else "legacy-") / ("partial" if partial else "clean")
                    root.parent.mkdir(exist_ok=True)
                    root.mkdir()
                    (root / MARKER).write_text("{}", encoding="ascii")
                    for relative in relatives:
                        target = root / relative
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_bytes(source_bytes(relative, v16))
                    if partial:
                        first = (REPO / "patches" / "versus-v16-death-respawn.json") if v16 else (REPO / "patches" / "restore-legacy-gameplay.json")
                        self.apply(root, first)
                    # Reverse filename order deliberately; hashes determine the order.
                    self.apply_batch(root, reversed(recipe_paths))
                    for relative in relatives:
                        entries = [e for r in recipes for e in r["files"] if e["path"] == relative]
                        inputs = {e["source_sha256"] for e in entries}
                        final = [e["result_sha256"] for e in entries if e["result_sha256"] not in inputs]
                        self.assertEqual(len(final), 1)
                        self.assertEqual(digest((root / relative).read_bytes()), final[0])
                    for recipe in recipes:
                        for entry in recipe["files"]:
                            backup = root / ".patch-backups" / recipe["name"] / entry["path"]
                            if backup.is_file():
                                self.assertEqual(digest(backup.read_bytes()), entry["source_sha256"])
                    before = tree_contents(root)
                    times = {p: p.stat().st_mtime_ns for p in root.rglob("*") if p.is_file()}
                    self.apply_batch(root, recipe_paths)
                    self.assertEqual(tree_contents(root), before)
                    self.assertEqual({p: p.stat().st_mtime_ns for p in times}, times)

    def test_synthetic_chain_preserves_binary_bytes_and_each_backup(self):
        states = [b"before\xff\r\n", b"middle\xff\r\n", b"after\xff\r\n"]
        root = self.synthetic_root(states[0])
        first = self.edge_recipe("z-first", states[0], states[1])
        second = self.edge_recipe("a-second", states[1], states[2])
        self.apply_batch(root, [second, first])
        self.assertEqual((root / "source.uc").read_bytes(), states[2])
        for name, expected in zip(("z-first", "a-second"), states):
            self.assertEqual((root / ".patch-backups" / name / "source.uc").read_bytes(), expected)

    def test_recognized_intermediate_needs_no_predecessor_backup(self):
        root = self.synthetic_root(b"middle\n")
        first = self.edge_recipe("first", b"before\n", b"middle\n")
        second = self.edge_recipe("second", b"middle\n", b"after\n")
        self.apply_batch(root, [second, first])
        self.assertEqual((root / "source.uc").read_bytes(), b"after\n")
        self.assertFalse((root / ".patch-backups" / "first").exists())
        self.assertEqual((root / ".patch-backups" / "second" / "source.uc").read_bytes(), b"middle\n")

    def test_final_state_needs_no_backups_and_has_no_writes(self):
        root = self.synthetic_root(b"after\n")
        first = self.edge_recipe("first", b"before\n", b"middle\n")
        second = self.edge_recipe("second", b"middle\n", b"after\n")
        before = tree_contents(root)
        self.apply_batch(root, [second, first])
        self.assertEqual(tree_contents(root), before)
        self.assertFalse((root / ".patch-backups").exists())

    def test_later_recipe_validation_failure_writes_nothing(self):
        root = self.synthetic_root()
        (root / "other.uc").write_bytes(b"before\n")
        first = self.edge_recipe("first", b"before\n", b"middle\n")
        other = self.edge_recipe("other", b"before\n", b"after\n", "other.uc")
        bad_entry = synthetic_entry("source.uc", b"middle\n", b"after\n")
        bad_entry["replacements"][0]["old"] = "absent"
        bad = write_recipe(self.temp / "bad.json", {"name": "bad", "files": [bad_entry]})
        before = tree_contents(root)
        with self.assertRaisesRegex(ValueError, "Non-unique patch anchor"):
            self.apply_batch(root, [other, first, bad])
        self.assertEqual(tree_contents(root), before)
        self.assertFalse((root / ".patch-backups").exists())

    def test_later_target_tampering_writes_nothing(self):
        root = self.synthetic_root()
        (root / "other.uc").write_bytes(b"tampered\n")
        first = self.edge_recipe("first", b"before\n", b"middle\n")
        other = self.edge_recipe("other", b"before\n", b"after\n", "other.uc")
        before = tree_contents(root)
        with self.assertRaisesRegex(ValueError, "Source hash mismatch"):
            self.apply_batch(root, [first, other])
        self.assertEqual(tree_contents(root), before)

    def test_fork_missing_predecessor_merge_and_cycle_rejected(self):
        root = self.synthetic_root()
        first = self.edge_recipe("first", b"before\n", b"middle\n")
        cases = [
            ("fork", b"before\n", b"fork\n", "Forked"),
            ("gap", b"missing\n", b"final\n", "missing predecessor"),
            ("merge", b"other\n", b"middle\n", "Ambiguous predecessor"),
            ("cycle", b"middle\n", b"before\n", "Cyclic"),
        ]
        for name, source, result, message in cases:
            with self.subTest(case=name):
                extra = self.edge_recipe(name, source, result)
                before = tree_contents(root)
                with self.assertRaisesRegex(ValueError, message):
                    self.apply_batch(root, [extra, first])
                self.assertEqual(tree_contents(root), before)

    def test_omitted_predecessor_cannot_patch_clean_input(self):
        root = self.synthetic_root()
        second = self.edge_recipe("second", b"middle\n", b"after\n")
        before = tree_contents(root)
        with self.assertRaisesRegex(ValueError, "Source hash mismatch"):
            self.apply_batch(root, [second])
        self.assertEqual(tree_contents(root), before)

    def test_backup_tampering_and_parent_conflict_rejected_before_writes(self):
        root = self.synthetic_root()
        recipe = self.edge_recipe("first", b"before\n", b"after\n")
        backup_parent = root / ".patch-backups" / "first"
        backup_parent.parent.mkdir()
        backup_parent.write_bytes(b"blocks directory")
        before = tree_contents(root)
        with self.assertRaisesRegex(ValueError, "parent is not a directory"):
            self.apply(root, recipe)
        self.assertEqual(tree_contents(root), before)
        backup_parent.unlink()
        backup_parent.mkdir()
        (backup_parent / "source.uc").write_bytes(b"corrupt backup")
        before = tree_contents(root)
        with self.assertRaisesRegex(ValueError, "Backup hash mismatch"):
            self.apply(root, recipe)
        self.assertEqual(tree_contents(root), before)

    def test_recipe_name_cannot_escape_backup_tree(self):
        root = self.synthetic_root()
        for name in ("../escape", "..\\escape", "C:\\escape", "", ".."):
            with self.subTest(name=name):
                path = write_recipe(self.temp / "unsafe-name.json",
                                    {"name": name, "files": [synthetic_entry("source.uc")]})
                before = tree_contents(root)
                with self.assertRaisesRegex(ValueError, "recipe name"):
                    self.apply(root, path)
                self.assertEqual(tree_contents(root), before)

    def test_target_and_backup_symlinks_rejected(self):
        root = self.synthetic_root()
        outside = self.temp / "outside.uc"
        outside.write_bytes(b"before\n")
        link = root / "link.uc"
        try:
            link.symlink_to(outside)
        except (OSError, NotImplementedError) as exc:
            self.skipTest(f"Symlink creation unavailable: {exc}")
        target_recipe = self.edge_recipe("linked", b"before\n", b"after\n", "link.uc")
        with self.assertRaisesRegex(ValueError, "escapes development tree|symlink"):
            self.apply(root, target_recipe)
        self.assertEqual(outside.read_bytes(), b"before\n")
        link.unlink()
        backup_dir = root / ".patch-backups" / "normal"
        backup_dir.mkdir(parents=True)
        (backup_dir / "source.uc").symlink_to(outside)
        normal = self.edge_recipe("normal", b"before\n", b"after\n")
        with self.assertRaisesRegex(ValueError, "escapes development tree|symlink"):
            self.apply(root, normal)
        self.assertEqual(outside.read_bytes(), b"before\n")
        self.assertEqual((root / "source.uc").read_bytes(), b"before\n")

    def test_api_rejects_unmarked_tree(self):
        root = self.temp / "unmarked-api"
        root.mkdir()
        (root / "source.uc").write_bytes(b"before\n")
        recipe = self.edge_recipe("unmarked", b"before\n", b"after\n")
        before = tree_contents(root)
        with self.assertRaisesRegex(ValueError, "without the development-copy marker"):
            self.apply(root, recipe)
        self.assertEqual(tree_contents(root), before)

    def test_cli_applies_full_batch_in_hash_order(self):
        root = self.synthetic_root()
        first = self.edge_recipe("z-first", b"before\n", b"middle\n")
        second = self.edge_recipe("a-second", b"middle\n", b"after\n")
        result = subprocess.run(
            [sys.executable, str(APPLIER_PATH), "--work-root", str(root), str(second), str(first)],
            cwd=self.temp, capture_output=True, text=True, timeout=15, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((root / "source.uc").read_bytes(), b"after\n")
        self.assertEqual((root / ".patch-backups" / "z-first" / "source.uc").read_bytes(), b"before\n")
        self.assertEqual((root / ".patch-backups" / "a-second" / "source.uc").read_bytes(), b"middle\n")

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
