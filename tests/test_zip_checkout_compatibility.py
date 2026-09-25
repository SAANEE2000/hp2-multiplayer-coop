import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ZipCheckoutCompatibilityTests(unittest.TestCase):
    def test_build_does_not_invoke_git_without_repo_marker(self):
        source = (ROOT / "Build.ps1").read_text(encoding="utf-8-sig")
        marker = "$repoGitMarker = Join-Path $repo '.git'"
        guard = "Test-Path -LiteralPath $repoGitMarker"
        git_call = "& git -C $repo rev-parse HEAD"
        self.assertIn(marker, source)
        self.assertIn(guard, source)
        self.assertIn(git_call, source)
        self.assertLess(source.index(guard), source.index(git_call))
        self.assertIn("$buildCommit = $null", source)
        self.assertIn("$buildBranch = $null", source)
        self.assertIn("$buildDirty = $null", source)

    def test_export_has_the_same_zip_checkout_guard(self):
        source = (ROOT / "scripts" / "Export-TestBuild.ps1").read_text(
            encoding="utf-8-sig"
        )
        guard = "Test-Path -LiteralPath (Join-Path $repo '.git')"
        git_call = "& git -C $repo rev-parse HEAD"
        self.assertIn(guard, source)
        self.assertIn(git_call, source)
        self.assertLess(source.index(guard), source.index(git_call))


if __name__ == "__main__":
    unittest.main()
