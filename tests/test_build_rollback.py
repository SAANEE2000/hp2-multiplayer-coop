import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class BuildRollbackTests(unittest.TestCase):
    def test_failed_ucc_keeps_last_good_packages_and_build_record(self):
        shell = shutil.which("pwsh") or shutil.which("powershell")
        compiler = shutil.which("where.exe")
        if not shell or not compiler:
            self.skipTest("Windows PowerShell and where.exe are required")

        with tempfile.TemporaryDirectory(dir=ROOT / ".local") as temporary:
            repo = Path(temporary)
            system = repo / "game" / "System"
            scripts = repo / "scripts"
            local = repo / ".local"
            system.mkdir(parents=True)
            scripts.mkdir()
            local.mkdir()
            shutil.copy2(ROOT / "Build.ps1", repo / "Build.ps1")
            (scripts / "Prepare-LocalGame.ps1").write_text(
                "param([string]$GameRoot, [string]$WorkRoot) Write-Output $WorkRoot\n",
                encoding="utf-8",
            )
            shutil.copy2(compiler, system / "UCC.exe")
            (system / "Default.ini").write_text(
                "[Core.System]\nUserFolder=Original\n", encoding="ascii"
            )
            (repo / "game" / ".hp2-development-copy.json").write_text("{}")
            originals = {"HGame.u": b"known-good-game", "M212Share.u": b"known-good-share"}
            for name, data in originals.items():
                (system / name).write_bytes(data)
            prior_record = b'{"passed":true,"hgameSha256":"previous"}'
            (local / "last-build.json").write_bytes(prior_record)

            result = subprocess.run(
                [shell, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                 "-File", str(repo / "Build.ps1"),
                 "-WorkRoot", str(repo / "game")],
                capture_output=True,
                text=True,
                timeout=30,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout)
            for name, data in originals.items():
                self.assertEqual((system / name).read_bytes(), data)
            self.assertEqual((local / "last-build.json").read_bytes(), prior_record)
            results = list((local / "builds").glob("*/result.json"))
            self.assertEqual(len(results), 1, result.stdout + result.stderr)
            self.assertIs(json.loads(results[0].read_text(encoding="utf-8-sig"))["passed"], False)


if __name__ == "__main__":
    unittest.main()
