"""Runtime manifest checks with synthetic files; no game assets or processes."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "Test-RuntimeCompatibility.ps1"
SHELL = os.environ.get("HP2_TEST_POWERSHELL") or shutil.which("pwsh") or shutil.which("powershell")
RUNTIME = ("System/Engine.dll", "System/Core.dll", "System/Game.exe", "System/UCC.exe",
           "System/Engine.u", "System/Core.u", "System/IpDrv.dll", "System/IpDrv.u",
           "Maps/Entry.unr", "Maps/Ch1Rictusempra.unr")


def inventory(root):
    return {str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file()}


@unittest.skipUnless(SHELL, "PowerShell required")
class RuntimeCompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hp2-runtime-manifest-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name).resolve()
        (self.repo / "scripts").mkdir()
        self.script = self.repo / "scripts" / SCRIPT.name
        shutil.copy2(SCRIPT, self.script)
        self.source = self.repo / "Own installation"
        self.work = self.repo / "Development copy"
        for relative in RUNTIME:
            path = self.source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(("Synthetic runtime " + relative).encode())
        shutil.copytree(self.source, self.work)
        (self.work / ".hp2-development-copy.json").write_text(json.dumps({"source": str(self.source)}))

    def run_check(self, *args, success=True, work=None):
        environment = {k: v for k, v in os.environ.items() if k.casefold() != "psmodulepath"}
        result = subprocess.run([SHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(self.script),
                                 "-WorkRoot", str(work or self.work), *map(str, args)],
                                capture_output=True, encoding="utf-8", errors="replace", timeout=30, env=environment)
        self.assertEqual(result.returncode, 0 if success else 1, result.stdout + result.stderr)
        return json.loads(result.stdout.lstrip("\ufeff"))

    def generate(self):
        result = self.run_check("-Generate")
        self.assertEqual(result["status"], "GENERATED")
        return Path(result["manifest"])

    def assert_readonly_rejection(self, manifest, codes):
        before = inventory(self.repo)
        result = self.run_check("-Manifest", manifest, success=False)
        self.assertEqual(result["status"], "INCOMPATIBLE")
        self.assertTrue(set(codes).issubset({i["code"] for i in result["issues"]}), result)
        self.assertEqual(inventory(self.repo), before)
        return result

    def test_generated_manifest_and_validation_leave_both_runtime_trees_unchanged(self):
        original = inventory(self.source)
        work_before = inventory(self.work)
        manifest = self.generate()
        self.assertEqual(manifest.parent, self.repo / ".local" / "distribution")
        document = json.loads(manifest.read_text(encoding="utf-8"))
        self.assertEqual({r["path"] for r in document["files"]}, set(RUNTIME))
        for record in document["files"]:
            value = (self.work / record["path"]).read_bytes()
            self.assertEqual(record["bytes"], len(value))
            self.assertEqual(record["sha256"], hashlib.sha256(value).hexdigest())
        self.assertNotIn(str(self.source), manifest.read_text())
        self.assertEqual(inventory(self.source), original)
        self.assertEqual(inventory(self.work), work_before)
        before = inventory(self.repo)
        result = self.run_check("-Manifest", manifest)
        self.assertEqual(result["status"], "COMPATIBLE")
        self.assertEqual(result["filesChecked"], 10)
        self.assertEqual(inventory(self.repo), before)

    def test_unmarked_original_cannot_generate_or_create_distribution(self):
        before = inventory(self.repo)
        result = self.run_check("-Generate", work=self.source, success=False)
        self.assertIn("UNMARKED", {i["code"] for i in result["issues"]})
        self.assertEqual(inventory(self.repo), before)
        self.assertFalse((self.repo / ".local").exists())

    def test_all_missing_entries_are_reported_before_launch(self):
        manifest = self.generate()
        missing = ("System/Engine.dll", "Maps/Entry.unr", "System/IpDrv.dll")
        for relative in missing:
            (self.work / relative).unlink()
        result = self.assert_readonly_rejection(manifest, {"MISSING"})
        self.assertEqual(len(result["issues"]), len(missing))

    def test_same_size_tamper_and_different_map_are_both_mismatches(self):
        manifest = self.generate()
        dll = self.work / "System/Core.dll"
        value = dll.read_bytes()
        dll.write_bytes(bytes([value[0] ^ 1]) + value[1:])
        (self.work / "Maps/Ch1Rictusempra.unr").write_bytes(b"different map")
        result = self.assert_readonly_rejection(manifest, {"MISMATCH"})
        self.assertEqual({i["path"] for i in result["issues"]}, {"System/Core.dll", "Maps/Ch1Rictusempra.unr"})

    def test_invalid_duplicate_missing_and_escape_manifest_records_refused(self):
        manifest = self.generate()
        original = json.loads(manifest.read_text())
        mutations = (
            lambda d: d["files"][0].update(path="../outside.dll"),
            lambda d: d["files"][0].update(path=d["files"][1]["path"]),
            lambda d: d["files"].pop(),
            lambda d: d["files"][0].update(sha256="not-a-hash"),
            lambda d: d["files"][0].update(bytes=1.5),
        )
        for mutate in mutations:
            document = json.loads(json.dumps(original))
            mutate(document)
            manifest.write_text(json.dumps(document))
            self.assert_readonly_rejection(manifest, {"INVALID_MANIFEST"})

    def test_directory_in_place_of_runtime_file_is_ambiguous(self):
        manifest = self.generate()
        target = self.work / "System/Game.exe"
        target.unlink()
        target.mkdir()
        self.assert_readonly_rejection(manifest, {"AMBIGUOUS"})

    def test_failed_generation_writes_no_partial_manifest(self):
        (self.work / "Maps/Entry.unr").write_bytes(b"")
        before = inventory(self.repo)
        result = self.run_check("-Generate", success=False)
        self.assertIn("UNREADABLE_OR_CHANGED", {i["code"] for i in result["issues"]})
        self.assertEqual(inventory(self.repo), before)
        self.assertFalse((self.repo / ".local").exists())


if __name__ == "__main__":
    unittest.main()
