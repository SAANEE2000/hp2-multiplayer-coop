"""The patch build must distinguish a real Python from a Windows Store alias."""

from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
FINDER = ROOT / "scripts" / "Find-Python3.ps1"


@unittest.skipUnless(sys.platform == "win32", "PowerShell Windows discovery test")
class PythonDiscoveryTests(unittest.TestCase):
    def run_finder(self, candidate):
        with tempfile.TemporaryDirectory(prefix="hp2-python-probe-") as temp:
            # Some Python test runners expose both Path and PATH; Windows
            # PowerShell's Start-Process rejects that duplicate environment key.
            environment = {key: value for key, value in os.environ.items()
                           if key.casefold() != "path"}
            environment["Path"] = os.environ.get("Path", os.environ.get("PATH", ""))
            return subprocess.run(
                ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                 str(FINDER), "-LogRoot", temp, "-CandidatePaths", str(candidate)],
                capture_output=True, text=True, errors="replace", check=False,
                env=environment,
            )

    def test_rejects_windows_store_stub_with_install_guidance(self):
        stub = Path("C:/Users/test/AppData/Local/Microsoft/WindowsApps/python.exe")
        result = self.run_finder(stub)
        self.assertNotEqual(result.returncode, 0)
        output = result.stdout + result.stderr
        self.assertIn("Python 3.9 or newer is required", output)
        self.assertIn("WindowsApps Store aliases do not count", output)

    def test_accepts_real_interpreter(self):
        if sys.version_info < (3, 9):
            self.skipTest("Test runner itself is older than Python 3.9")
        result = self.run_finder(Path(sys.executable))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Python 3.", result.stdout)


if __name__ == "__main__":
    unittest.main()
