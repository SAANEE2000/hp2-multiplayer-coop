"""Package a committed source snapshot with a verified private test build/map."""

import argparse
import hashlib
import io
import json
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DONOR_HASH = "A2B13B924BF9BBA9F81C6A70E38024657C71F6F1F861FA49BF3F812C86EFB9BF"
STARTUP_HASH = "77AA6B898B5297A3663E6A4544CC3A2BE37ACC3CF6F74F55A3FF7C6EBAF9F7B8"
ARENA_HASH = "25A8168CE20520179A24542DC75F0C649B07443BC8450420E176938992659D49"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def checked(path: Path, expected: str) -> bytes:
    data = path.read_bytes()
    actual = digest(data)
    if actual != expected:
        raise ValueError(f"SHA-256 mismatch for {path}: {actual} expected {expected}")
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", type=Path, required=True,
                        help="ZIP returned by Export-TestBuild.ps1")
    parser.add_argument("--arena", type=Path,
                        default=ROOT / ".local/versus-v16-game/Maps/Arena_Grounds_hub.unr")
    parser.add_argument("--startup", type=Path,
                        default=ROOT / ".local/versus-v16-game/Maps/startup.unr")
    args = parser.parse_args()
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    branch = subprocess.check_output(["git", "branch", "--show-current"], cwd=ROOT, text=True).strip()
    if branch != "codex/versus-8-spawn-map":
        raise ValueError(f"Expected Versus branch, got {branch!r}")

    donor = checked(ROOT / "HPVersus_v16_remote_bottom_align_20260905.zip", DONOR_HASH)
    startup = checked(args.startup, STARTUP_HASH)
    arena = checked(args.arena, ARENA_HASH)
    artifact = args.artifact.read_bytes()
    with zipfile.ZipFile(io.BytesIO(artifact)) as build_zip:
        build_manifest = json.loads(build_zip.read("manifest.json"))
        for entry in build_manifest["files"]:
            actual = digest(build_zip.read(entry["name"]))
            if actual.casefold() != entry["sha256"].casefold():
                raise ValueError(f"Build artifact entry mismatch: {entry['name']}")
        if not build_manifest["sourceBuild"]["versusV16"]:
            raise ValueError("Artifact is not a Versus v16 build")
        if build_manifest["sourceBuild"].get("commit") != commit:
            raise ValueError("Build artifact was not compiled from the committed source snapshot")
        compile_log = build_zip.read("ucc-output.log")
        if b"Success - 0 error(s)" not in compile_log:
            raise ValueError("Artifact has no successful compiler log")

    source = subprocess.check_output(["git", "archive", "--format=zip", "HEAD"], cwd=ROOT)
    payloads = {
        "HPVersus_v16_remote_bottom_align_20260905.zip": donor,
        "private-test/hp2-versus-arena-build.zip": artifact,
        "private-test/Maps/startup.unr": startup,
        "private-test/Maps/Arena_Grounds_hub.unr": arena,
        "private-test/ucc-output.log": compile_log,
    }
    readme = (
        f"HP2 Versus Arena Grounds private test kit\n"
        f"Branch: {branch}\nCommit: {commit}\n\n"
        "1. Install/keep your own HP2 M212 and extract this ZIP to C:\\HP2MP.\n"
        "2. In PowerShell from that folder run:\n"
        "   .\\scripts\\Setup-ArenaGroundsTestKit.ps1 -GameRoot 'PATH_TO_INSTALLED_HP2'\n"
        "3. Run Play-Menu-Test.cmd > Versus > Free For All > Arena Grounds Hub.\n"
        "4. Join on the other PC with the host's IPv4 address; joiners do not select a map.\n\n"
        "The donor archive, Arena map and verified HGame.u/M212Share.u build are included.\n"
        "The original map bytes are intact; the server supplies the missing eighth spawn.\n"
        "All six spell-fire cooldowns are disabled in this test build.\n"
        "Python is not needed when installing the included build. For a source rebuild,\n"
        "install Python 3.9+ and run .\\Build.ps1 -VersusV16 after setup.\n"
        "Keep this kit private; game packages/maps are not published in Git.\n"
        "For a network bug, close the game and collect each PC's session with:\n"
        "   .\\scripts\\Launch-Multiplayer.ps1 -CollectSession SESSION_ID\n"
        "Send the resulting .local/runs/SESSION_ID folders from both PCs.\n"
    ).encode("utf-8")
    payloads["README_FOR_FRIEND.txt"] = readme
    manifest = {
        "kind": "hp2-versus-arena-full-test", "branch": branch, "commit": commit,
        "mapPackage": "Arena_Grounds_hub", "mapModified": False,
        "buildSourceCommit": build_manifest["sourceBuild"].get("commit"),
        "packages": {entry["name"]: entry["sha256"].upper()
                     for entry in build_manifest["files"]
                     if entry["name"] in ("HGame.u", "M212Share.u")},
        "files": {name: {"bytes": len(data), "sha256": digest(data)}
                  for name, data in payloads.items()},
    }
    payloads["KIT_MANIFEST.json"] = json.dumps(manifest, indent=2).encode("utf-8")
    distribution = ROOT / ".local/distribution"
    distribution.mkdir(parents=True, exist_ok=True)
    output = distribution / f"hp2-versus-arena-FULL-TEST-{commit[:7]}.zip"
    if output.exists():
        raise FileExistsError(f"Preserving existing bundle: {output}")
    with zipfile.ZipFile(io.BytesIO(source)) as source_zip:
        with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as out:
            names = set()
            for entry in source_zip.infolist():
                if entry.is_dir():
                    continue
                names.add(entry.filename)
                out.writestr(entry, source_zip.read(entry))
            for name, data in payloads.items():
                if name in names:
                    raise ValueError(f"Duplicate ZIP member: {name}")
                out.writestr(name, data)
    with zipfile.ZipFile(output) as check:
        if check.testzip() is not None:
            raise ValueError("Bundle ZIP integrity check failed")
        for name, data in payloads.items():
            if digest(check.read(name)) != digest(data):
                raise ValueError(f"Bundle payload changed: {name}")
    print(f"bundle={output}\nsha256={digest(output.read_bytes())}\nbytes={output.stat().st_size}")


if __name__ == "__main__":
    main()
