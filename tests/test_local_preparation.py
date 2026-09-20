"""Prepare/import-only PCs must select a separate native M212 profile."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "Prepare-LocalGame.ps1"
SHELL = os.environ.get("HP2_TEST_POWERSHELL") or shutil.which("pwsh") or shutil.which("powershell")


@unittest.skipUnless(os.name == "nt" and SHELL, "Windows PowerShell/robocopy required")
class LocalPreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hp2-prepare-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "Own installation"
        self.target = self.root / "Development copy"
        (self.source / "System").mkdir(parents=True)
        # Fixture bytes only; this executable is never launched.
        (self.source / "System" / "UCC.exe").write_bytes(b"not an executable")
        self.original = b"[Core.System]\r\nUserFolder=OriginalGameProfile\r\nOtherSetting=keep\r\n"
        (self.source / "System" / "Default.ini").write_bytes(self.original)

    def run_prepare(self):
        environment = {key: value for key, value in os.environ.items() if key.casefold() != "psmodulepath"}
        return subprocess.run([SHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT),
                               "-GameRoot", str(self.source), "-WorkRoot", str(self.target)],
                              capture_output=True, timeout=30, check=False, env=environment)

    def assert_isolated(self):
        config = self.target / "System" / "Default.ini"
        self.assertIn(b"UserFolder=HP2-Multiplayer-Development", config.read_bytes())
        self.assertIn(b"OtherSetting=keep", config.read_bytes())
        self.assertEqual((self.source / "System" / "Default.ini").read_bytes(), self.original)
        self.assertEqual((self.target / "System" / "Default.ini.supplied").read_bytes(), self.original)
        self.assertTrue((self.target / ".hp2-development-copy.json").is_file())

    def test_fresh_copy_isolates_profile_without_a_build_and_repeat_preserves_it(self):
        result = self.run_prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_isolated()
        files = [p for p in self.target.rglob("*") if p.is_file()]
        before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in files}
        result = self.run_prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in files})

    def test_existing_marked_copy_repairs_old_profile_without_touching_source(self):
        shutil.copytree(self.source, self.target)
        (self.target / ".hp2-development-copy.json").write_text(json.dumps({"source": str(self.source)}))
        result = self.run_prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_isolated()

    def test_ambiguous_native_profile_is_rejected_before_marking_copy_ready(self):
        (self.source / "System" / "Default.ini").write_bytes(self.original + b"UserFolder=Second\r\n")
        result = self.run_prepare()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"Expected exactly one UserFolder", result.stderr)
        self.assertFalse((self.target / ".hp2-development-copy.json").exists())


if __name__ == "__main__":
    unittest.main()
