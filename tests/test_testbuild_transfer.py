"""Private transfer integration checks with synthetic bytes, never retail assets.

Runs the real PowerShell scripts from an isolated temporary repository. The
minimal package headers exercise integrity/transfer rules, not the game loader.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
import warnings
import zipfile


REPO = Path(__file__).resolve().parents[1]
POWERSHELL = os.environ.get("HP2_TEST_POWERSHELL") or shutil.which("pwsh") or shutil.which("powershell")


def digest(value):
    return hashlib.sha256(value).hexdigest()


def files(root):
    return {str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file()}


@unittest.skipUnless(POWERSHELL, "PowerShell required")
class TestBuildTransfer(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="hp2-transfer-tests-")
        self.addCleanup(self.temporary.cleanup)
        self.repo = Path(self.temporary.name).resolve()
        self.scripts = self.repo / "scripts"
        self.scripts.mkdir()
        for name in ("Export-TestBuild.ps1", "Import-TestBuild.ps1"):
            shutil.copy2(REPO / "scripts" / name, self.scripts / name)
        self.source = self.repo / "source"
        self.target = self.repo / "target"
        self.packages = {}
        for root in (self.source, self.target):
            (root / "System").mkdir(parents=True)
            (root / ".hp2-development-copy.json").write_text("{}")
        for index, name in enumerate(("HGame.u", "M212Share.u")):
            value = struct.pack("<14I", 0x9E2A83C1, 115, *([0] * 12)) + bytes([index + 1]) * 200
            self.packages[name] = value
            (self.source / "System" / name).write_bytes(value)
            (self.target / "System" / name).write_bytes(b"previous-" + name.encode())
        self.local = self.repo / ".local"
        self.local.mkdir()
        self.log = self.local / "ucc-output.log"
        self.log.write_text("Success - 0 error(s), 2 warnings\n", encoding="utf-8")
        self.build_record = self.local / "last-build.json"
        self.build = dict(passed=True, exitCode=0, baseline=False, workRoot=str(self.source),
                          hgameSha256=digest(self.packages["HGame.u"]), log=str(self.log))
        self.write_build()

    def write_build(self):
        self.build_record.write_text(json.dumps(self.build), encoding="utf-8")

    def run_script(self, script, *args, success=True):
        # A Python child of PowerShell 7 otherwise forwards its module search
        # path into Windows PowerShell 5.1, hiding the latter's script cmdlets.
        environment = {key: value for key, value in os.environ.items() if key.casefold() != "psmodulepath"}
        result = subprocess.run([POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                                 str(self.scripts / script), *map(str, args)],
                                capture_output=True, encoding="utf-8", errors="replace", timeout=30, env=environment)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return json.loads(result.stdout.lstrip("\ufeff"))
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def export(self):
        result = self.run_script("Export-TestBuild.ps1", "-WorkRoot", self.source)
        artifact = Path(result["artifact"])
        self.assertEqual(artifact.parent, self.local / "distribution")
        self.assertEqual(digest(artifact.read_bytes()), result["sha256"])
        return artifact

    def rewrite_archive(self, original, transform, suffix="altered"):
        with zipfile.ZipFile(original) as archive:
            entries = [(item.filename, archive.read(item)) for item in archive.infolist()]
        entries = transform(entries)
        target = original.with_name(suffix + ".zip")
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(target, "w") as archive:
                for name, value in entries:
                    archive.writestr(name, value)
        return target

    def assert_rejected_without_writes(self, artifact):
        before = files(self.repo)
        self.run_script("Import-TestBuild.ps1", "-Artifact", artifact, "-WorkRoot", self.target, success=False)
        self.assertEqual(files(self.repo), before)

    def test_roundtrip_validation_backups_and_honest_origin(self):
        artifact = self.export()
        before = files(self.repo)
        validated = self.run_script("Import-TestBuild.ps1", "-Artifact", artifact, "-WorkRoot", self.target, "-ValidateOnly")
        self.assertEqual(validated["status"], "VALIDATED")
        self.assertEqual(files(self.repo), before)
        source_before = files(self.source)
        previous_record = self.build_record.read_bytes()
        imported = self.run_script("Import-TestBuild.ps1", "-Artifact", artifact, "-WorkRoot", self.target)
        self.assertEqual(imported["origin"], "imported-test-build")
        self.assertFalse(imported["localUccRun"])
        self.assertIsNone(imported["exitCode"])
        self.assertTrue(imported["artifactIntegrityVerified"])
        self.assertTrue(imported["sourceBuild"]["passed"])
        self.assertFalse(imported["baseline"])
        backups = Path(imported["importRoot"])
        for name, value in self.packages.items():
            self.assertEqual((self.target / "System" / name).read_bytes(), value)
            self.assertEqual((backups / (name + ".before")).read_bytes(), b"previous-" + name.encode())
        self.assertEqual((backups / "last-build.json.before").read_bytes(), previous_record)
        self.assertEqual(json.loads(self.build_record.read_text()), imported)
        self.assertEqual(files(self.source), source_before)
        reexported = self.run_script("Export-TestBuild.ps1", "-WorkRoot", self.target)
        self.assertEqual(reexported["sourceBuild"], imported["sourceBuild"])

    def test_tampered_second_package_rejected_before_any_write(self):
        artifact = self.export()
        tampered = self.rewrite_archive(artifact, lambda entries: [(n, v + b"tampered" if n == "M212Share.u" else v) for n, v in entries])
        self.assert_rejected_without_writes(tampered)

    def test_extra_duplicate_and_traversal_entries_rejected(self):
        artifact = self.export()
        transforms = [lambda e: e + [("extra.txt", b"x")],
                      lambda e: [("../HGame.u" if n == "HGame.u" else n, v) for n, v in e],
                      lambda e: [("HGame.u" if n == "M212Share.u" else n, v) for n, v in e]]
        for index, transform in enumerate(transforms):
            with self.subTest(index=index):
                self.assert_rejected_without_writes(self.rewrite_archive(artifact, transform, "invalid-" + str(index)))

    def test_unmarked_target_rejected(self):
        artifact = self.export()
        (self.target / ".hp2-development-copy.json").unlink()
        self.assert_rejected_without_writes(artifact)

    def test_failed_source_build_or_changed_recorded_package_cannot_export(self):
        for mutation in ({"passed": False}, {"passed": True, "hgameSha256": "0" * 64}):
            self.build.update(mutation)
            self.write_build()
            before = files(self.repo)
            self.run_script("Export-TestBuild.ps1", "-WorkRoot", self.source, success=False)
            self.assertEqual(files(self.repo), before)

    def test_failed_log_rejected_even_with_matching_hash(self):
        artifact = self.export()
        def mutate(entries):
            values = dict(entries)
            values["ucc-output.log"] += b"Critical: synthetic failure\n"
            manifest = json.loads(values["manifest.json"])
            for record in manifest["files"]:
                if record["name"] == "ucc-output.log":
                    record.update(bytes=len(values["ucc-output.log"]), sha256=digest(values["ucc-output.log"]))
            values["manifest.json"] = json.dumps(manifest).encode()
            return list(values.items())
        self.assert_rejected_without_writes(self.rewrite_archive(artifact, mutate))

    def test_baseline_flag_preserved(self):
        self.build["baseline"] = True
        self.write_build()
        artifact = self.export()
        imported = self.run_script("Import-TestBuild.ps1", "-Artifact", artifact, "-WorkRoot", self.target)
        self.assertTrue(imported["baseline"])
        self.assertTrue(imported["sourceBuild"]["baseline"])

    def test_matching_process_guard_rejects_before_writes(self):
        artifact = self.export()
        harness = self.scripts / "Test-RunningProcess.ps1"
        harness.write_text('''param([string]$Artifact,[string]$WorkRoot)
function Get-Process { [PSCustomObject]@{Id=12345; Path=(Join-Path $WorkRoot 'System\\UCC.exe')} }
& (Join-Path $PSScriptRoot 'Import-TestBuild.ps1') -Artifact $Artifact -WorkRoot $WorkRoot
''', encoding="utf-8")
        before = files(self.repo)
        self.run_script(harness.name, "-Artifact", artifact, "-WorkRoot", self.target, success=False)
        self.assertEqual(files(self.repo), before)

    def test_replacement_failure_restores_previous_packages_and_record(self):
        artifact = self.export()
        harness = self.scripts / "Test-ReplacementFailure.ps1"
        harness.write_text('''param([string]$Artifact,[string]$WorkRoot)
Import-Module Microsoft.PowerShell.Utility
function Get-FileHash {
    param([string]$LiteralPath,[string]$Algorithm)
    if ($LiteralPath -eq (Join-Path $WorkRoot 'System\\HGame.u')) { throw 'Injected post-replacement verification failure' }
    Microsoft.PowerShell.Utility\\Get-FileHash -LiteralPath $LiteralPath -Algorithm $Algorithm
}
& (Join-Path $PSScriptRoot 'Import-TestBuild.ps1') -Artifact $Artifact -WorkRoot $WorkRoot
''', encoding="utf-8")
        previous_packages = files(self.target)
        previous_record = self.build_record.read_bytes()
        self.run_script(harness.name, "-Artifact", artifact, "-WorkRoot", self.target, success=False)
        self.assertEqual(files(self.target), previous_packages)
        self.assertEqual(self.build_record.read_bytes(), previous_record)
        self.assertEqual(len(list((self.local / "imports").glob("*/HGame.u.before"))), 1)
        self.assertFalse(list(self.repo.rglob("*.tmp")))


if __name__ == "__main__":
    unittest.main()
