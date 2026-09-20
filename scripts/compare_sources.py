"""Compare local HP2 snapshots and upstream Git blobs; publish metadata only.

Requires Python 3.10+ and Git. Missing upstream blobs are fetched only with
--fetch-missing, into the ignored .local/upstream clone. No source is copied
into the public repository, and no checkout, root Git mutation, or build occurs.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[1]
HANDOFF = ROOT / "HPVersus_Local_Codex_Handoff_20260920"
OLD_COMMIT = "7105bae78ee2e7c5a3b4d2dff65e1ea7cc903e8b"
NEW_COMMIT = "d052c5bdb3ed2e232fa0f71d0189880d585b295d"
UPSTREAM_URL = "https://github.com/metallicafan212/HP2UScriptDecompile"


def display_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return path.resolve().as_posix()


def git(repo: Path, *args: str, data: bytes | None = None) -> bytes:
    env = os.environ.copy()
    # A metadata inspection must not silently request network authentication.
    env["GIT_NO_LAZY_FETCH"] = "1"
    env["GIT_TERMINAL_PROMPT"] = "0"
    result = subprocess.run(
        ["git", "-C", str(repo), *args], input=data,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace").strip())
    return result.stdout


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalize(data: bytes) -> bytes:
    """Ignore whitespace, but retain whitespace and escapes inside literals.

    Latin-1 is lossless for bytes; this does not pretend all historical source
    files have the same text encoding. Comments are retained. A changed comment
    therefore remains a source change; this is not a semantic equivalence test.
    """
    text = data.decode("latin-1")
    if text.startswith("\xef\xbb\xbf"):
        text = text[3:]
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|\S', text)
    return "".join(tokens).encode("latin-1")


def add_source(result: dict, path: str, data: bytes) -> None:
    path = path.replace("\\", "/")
    if not path.lower().endswith(".uc"):
        return
    key = path.casefold()
    if key in result:
        raise ValueError(f"Duplicate source path: {path}")
    result[key] = {
        "path": path, "sha256": digest(data),
        "normalized_sha256": digest(normalize(data)), "bytes": len(data),
    }


def folder_sources(folder: Path) -> dict:
    if not folder.is_dir():
        raise FileNotFoundError(folder)
    result: dict = {}
    for path in sorted(folder.rglob("*")):
        if path.is_file() and path.suffix.lower() == ".uc":
            add_source(result, path.relative_to(folder).as_posix(), path.read_bytes())
    return result


def archive_sources(path: Path) -> dict:
    result: dict = {}
    with zipfile.ZipFile(path) as archive:
        for item in archive.infolist():
            name = item.filename.replace("\\", "/")
            match = re.search(r"(?:^|/)Classes/(.+\.uc)$", name, re.IGNORECASE)
            if match:
                add_source(result, match.group(1), archive.read(item))
    if not result:
        raise ValueError(f"No Classes/*.uc found in {path}")
    return result


def tree_sources(repo: Path, commit: str) -> dict[str, str]:
    result = {}
    for record in git(repo, "ls-tree", "-rz", commit, "--", "HGame/Classes").split(b"\0"):
        if not record:
            continue
        meta, path = record.split(b"\t", 1)
        _mode, kind, oid = meta.split()
        name = path.decode("utf-8")
        if kind == b"blob" and name.lower().endswith(".uc"):
            result[name.removeprefix("HGame/Classes/")] = oid.decode("ascii")
    if not result:
        raise ValueError(f"No HGame/Classes sources in upstream commit {commit}")
    return result


def get_blobs(repo: Path, object_ids: set[str], fetch_missing: bool) -> dict[str, bytes]:
    request = ("\n".join(sorted(object_ids)) + "\n").encode("ascii")
    checks = git(repo, "cat-file", "--batch-check=%(objectname) %(objecttype)", data=request)
    missing = [line.split()[0].decode("ascii") for line in checks.splitlines()
               if line.endswith(b" missing")]
    if missing:
        if not fetch_missing:
            raise RuntimeError(
                f"{len(missing)} upstream source blobs missing locally. "
                "Rerun with --fetch-missing to fetch only requested source objects."
            )
        print(f"Fetching {len(missing)} source blobs into {repo}.", flush=True)
        git(repo, "-c", "fetch.negotiationAlgorithm=noop", "fetch",
            "--no-tags", "--no-write-fetch-head", "--no-filter",
            "--no-auto-maintenance", "--recurse-submodules=no", "origin", "--stdin",
            data=("\n".join(missing) + "\n").encode("ascii"))
    batch = git(repo, "cat-file", "--batch", data=request)
    result = {}
    offset = 0
    for expected in sorted(object_ids):
        line_end = batch.index(b"\n", offset)
        fields = batch[offset:line_end].split()
        if len(fields) != 3 or fields[1] != b"blob":
            raise RuntimeError(f"Cannot read upstream source blob {expected}")
        oid, _kind, size_text = fields
        size = int(size_text)
        start = line_end + 1
        result[oid.decode("ascii")] = batch[start:start + size]
        offset = start + size + 1
    return result


def compare(old: dict, new: dict) -> dict:
    result = {key: [] for key in ("added", "removed", "changed", "whitespace_only", "identical")}
    for key in sorted(old.keys() | new.keys()):
        if key not in old:
            result["added"].append(new[key]["path"])
        elif key not in new:
            result["removed"].append(old[key]["path"])
        elif old[key]["sha256"] == new[key]["sha256"]:
            result["identical"].append(new[key]["path"])
        elif old[key]["normalized_sha256"] == new[key]["normalized_sha256"]:
            result["whitespace_only"].append(new[key]["path"])
        else:
            result["changed"].append(new[key]["path"])
    return result


def publish_capability() -> dict:
    candidates = [Path("C:/Program Files/GitHub CLI/gh.exe"),
                  Path("C:/Program Files (x86)/GitHub CLI/gh.exe")]
    local_app = os.environ.get("LOCALAPPDATA")
    user_profile = os.environ.get("USERPROFILE")
    if local_app:
        candidates += [Path(local_app) / "Programs/GitHub CLI/gh.exe",
                       Path(local_app) / "Microsoft/WinGet/Links/gh.exe"]
    if user_profile:
        candidates += [Path(user_profile) / "scoop/shims/gh.exe"]
    try:
        helpers = git(ROOT, "config", "--get-all", "credential.helper").decode().splitlines()
    except RuntimeError:
        helpers = []
    kinds = []
    for helper in helpers:
        if re.fullmatch(r"(?:manager|manager-core)(?:\.exe)?", helper.strip()):
            kinds.append("manager")
        elif helper.strip() in ("store", "cache", "wincred"):
            kinds.append(helper.strip())
        else:
            kinds.append("custom (value redacted)")
    return {
        "gh_on_path": bool(shutil.which("gh")),
        "standard_gh_candidates": {str(path): path.is_file() for path in candidates},
        "credential_helper_configured": bool(helpers),
        "credential_helper_kinds": sorted(set(kinds)),
        "manager_binary_present": Path("C:/Program Files/Git/mingw64/bin/git-credential-manager.exe").is_file(),
        "GH_TOKEN_present": bool(os.environ.get("GH_TOKEN")),
        "GITHUB_TOKEN_present": bool(os.environ.get("GITHUB_TOKEN")),
        "authentication_verified": False,
    }


def render_report(snapshots: dict, pairs: dict, metadata: dict, capability: dict) -> str:
    lines = [
        "# Source comparison and publish capability", "",
        f"Generated UTC: {metadata['generated_utc']}. Reproduce with `{metadata['reproduce']}`.", "",
        "The supplied archives, v18 and installed source directories must exist. An existing clone of the upstream Scaling-Patch branch belongs at `.local/upstream` (override with `--upstream`); both commits below must be fetched. If source blobs are missing from a partial clone, add `--fetch-missing` once. Subsequent runs are offline. The fetch uses explicit source object IDs and does not update branches or check out files.", "",
        "This report contains source names, counts and source-derived findings only. Full upstream blobs remain in ignored `.local/upstream`; full manifests remain in ignored `.local/source-comparison.json`. No retail binaries/assets or decompiled source are copied into tracked paths.", "",
        "## Inputs and method", "",
        "Scope is HGame `Classes/**/*.uc`. Directory and archive names are compared case-insensitively. SHA-256 identifies exact equality; a second hash ignores whitespace outside quoted literals and a UTF-8 BOM. Comments are retained. Thus `changed` means a source change beyond formatting, not proof of a behavioral change. UTF-8/legacy encodings are not silently transcoded.", "",
        "| Snapshot | Classes | Source |", "| --- | ---: | --- |",
    ]
    for name, source in snapshots.items():
        lines.append(f"| {name} | {len(source)} | {metadata['inputs'][name]} |")
    lines += ["", "Upstream commit dates are commit metadata, not release or verified-build dates:", ""]
    for ref, info in metadata["upstream_commits"].items():
        lines.append(f"- [{ref}]({UPSTREAM_URL}/commit/{ref}): {info}.")
    lines += ["", "## Comparison counts", "",
              "Each row is old → new; additions/removals are relative to the old source set.", "",
              "| Comparison | Added | Removed | Changed | Whitespace only | Byte-identical |",
              "| --- | ---: | ---: | ---: | ---: | ---: |"]
    for label, result in pairs.items():
        counts = [len(result[key]) for key in ("added", "removed", "changed", "whitespace_only", "identical")]
        lines.append(f"| {label} | " + " | ".join(map(str, counts)) + " |")
    lines += ["", "## Changed source classes", "",
              "All paths below are relative to `HGame/Classes` (or the archive's `Classes`). Formatting-only files are counted above and omitted below; their names/hashes remain in the local manifest."]
    for label, result in pairs.items():
        if label == "installed → v18":
            continue
        lines += ["", f"### {label}", ""]
        meaningful = False
        for key in ("added", "removed", "changed"):
            if result[key]:
                meaningful = True
                lines += [f"{key.title()} ({len(result[key])}):", ""]
                lines += [f"- `{path}`" for path in result[key]]
                lines.append("")
        if not meaningful:
            lines.append("No source-set or non-formatting changes.")
    installed = pairs["installed → v18"]
    same = not any(installed[key] for key in ("added", "removed", "changed", "whitespace_only"))
    lines += ["", "## Findings and integration boundaries", "",
              f"- Installed HGame source equals the supplied v18 source byte-for-byte: **{'YES' if same else 'NO'}**. This establishes source snapshot identity only, not identity with compiled HGame.u or successful UCC compilation.",
              "- Audited v16 contains multiplayer movement/camera/ownership corrections. Its original baseWand, baseSpell, SpellCursor, BaseCam and BaseCamTarget remain unchanged in v18; campaign compatibility is not established by Versus fixes. See `docs/audits/SPELL_CONTEXT_AUDIT.md` for exact source lines.",
              "- v18 is a development candidate with additional combat, character and hide/seek work; a `version=16` log marker does not identify its actual source. Preserve it independently while bringing co-op up from a clean build.",
              "- Against historical upstream 7105bae, the supplied v18 changes exactly three existing HGame classes: Director, harry and Internal/HPConsole. All other differences are added classes; the original spell/camera/AI source trees are largely untouched.",
              "- Supplied v18 Director.OnPlayerPossessed (`Director.uc:105–135`) clears capture, disables death, sets Health=100 and forces the standard camera. Supplied `harry.uc:2288` replaces original Harry damage processing with an authority gate plus Super.TakeDamage (it is not strictly a no-op); `KillHarryWithClub:1602` does nothing; `KillHarry:1565` adds broad death guards. These are inherited campaign/single-player regressions to reconcile against upstream, not neutral multiplayer hooks. The input-routing work in `Internal/HPConsole.uc:580` onward also deserves preservation and review rather than wholesale replacement.",
              "- HGame differs between 7105bae and d052c5b only in `Props/chestbronze.uc`: the newer upstream adds the optional `bSpawnAllAtOnce` property and skips per-object ejection sleeps when enabled, alongside formatting/comment cleanup. It is an independent chest option, not a networking fix. Installed/v18 retains the older chest implementation.",
              "- The supplied `HPCoopGame.uc` is already present among additions relative to upstream, including in the v7 snapshot. Its existence is not evidence of a working campaign architecture; it is a minimal GameInfo/PostLogin experiment. A new co-op foundation must replace that experiment deliberately rather than create a duplicate class declaration.",
              "- Upstream comparison is against the exact requested historical commits. Upstream fixes and local multiplayer changes must be merged by class/function; do not replace the installed tree wholesale or treat every upstream difference as a multiplayer regression.",
              "- Whitespace equivalence is a review filter, not an UnrealScript parser or test. This script does not compile, run gameplay, prove authority, or establish two-PC compatibility.",
              "", "## Safe public-publish capability", "",
              f"- GitHub CLI on PATH: **{capability['gh_on_path']}**. Present at a checked standard install path: **{any(capability['standard_gh_candidates'].values())}**.",
              f"- Git credential helper configured: **{capability['credential_helper_configured']}**; sanitized type(s): **{', '.join(capability['credential_helper_kinds']) or 'none'}**. Git Credential Manager executable present: **{capability['manager_binary_present']}**.",
              f"- GH_TOKEN/GITHUB_TOKEN environment variables present: **{capability['GH_TOKEN_present']} / {capability['GITHUB_TOKEN_present']}**. Values were not printed, stored, or queried through credential fill.",
              "- A configured credential helper does not prove GitHub authentication, push authorization or repository-creation permission. No auth or remote write was attempted by this comparison task.",
              "- Parent task reports an authenticated GitHub connector as `SAANEE2000`, but no repository-creation tool. Connector authentication and Git CLI credentials are separate capabilities.",
              "- Safe route: create the requested public repository through an authorized UI/API capability or available GitHub CLI, then push only the allowlisted mod/patch/script/config/doc/test tree after checking staged/tracked paths. Keep `.local`, supplied snapshots, full decompile, binaries and assets excluded. Do not assume the credential helper can create a repository; authentication must be confirmed by a supported operation without exposing credentials.",
              ""]
    recipe_path = ROOT / "patches/restore-legacy-gameplay.json"
    if recipe_path.is_file():
        recipe = json.loads(recipe_path.read_text(encoding="ascii"))
        lines += ["## Narrow legacy-gameplay restoration recipe", "",
                  "Recipe: `patches/restore-legacy-gameplay.json`. This comparison task generated and validated the recipe in memory; it did **not** apply it to gameplay sources. The complete file is ASCII JSON with byte-preserving Latin-1 strings. Encode each decoded `old`/`new` value as Latin-1 before exact byte replacement. Do not normalize newlines or decode original source as UTF-8 when applying these replacements.", "",
                  "Original means upstream 7105bae. These two upstream files are also unchanged at d052c5b. Line ranges are diagnostic only; the patch requires whole-file input SHA and a unique exact old byte sequence, then validates the complete expected result SHA before writing a development copy.", "",
                  "| File / global function | v18 lines | Original lines | Action |",
                  "| --- | --- | --- | --- |"]
        for item in recipe["files"]:
            for op in item["replacements"]:
                source = "–".join(map(str, op["source_lines"]))
                upstream = "–".join(map(str, op["upstream_lines"])) if op["upstream_lines"] else "absent"
                action = "Restore original function" if op["new"] else "Remove added override; inherit original behavior"
                lines.append(f"| {item['path']} / {op['function']} | {source} | {upstream} | {action} |")
        lines += ["", "Whole-file preconditions and expected results:", ""]
        for item in recipe["files"]:
            lines += [f"- `{item['path']}` input: `{item['source_sha256']}`; result: `{item['result_sha256']}`."]
        lines += ["", "Why these seven hunks belong together:", "",
                  "- KillHarry regains the original Director/boss/death-state flow. KillHarryWithClub regains its club-death flag and rotation. TakeDamage regains Harry-specific status, difficulty, potion, knockback, hurt/boss notification and death behavior instead of delegating all processing to PlayerPawn.",
                  "- Timer regains only SleepyAnimTimerSub. v18 had added Super.Timer, an unconditional Health=100 / bAllowHarryToDie=False reset, and a client branch forcing input, walking physics and standard camera. Fixing TakeDamage while retaining this Timer would silently undo damage and special states later.",
                  "- Added PostNetBeginPlay uses Role<Authority, which includes remote simulated pawns; it clears capture and redirects camera to whichever pawn executes. Removing the global override preserves subclass-owned local bootstrap and the existing Versus override.",
                  "- Added global Tick forces standard camera whenever the camera is in any other mode, including cutscene/boss modes. Removing it restores inherited behavior; existing state-specific Tick methods and Versus Tick remain untouched.",
                  "- Director.OnPlayerPossessed regains its original console binding only. Campaign possession must not reset health, disable death, clear capture, or force camera mode globally. A dedicated-safe/local-context Director override still belongs in the new co-op foundation.", "",
                  "The recipe deliberately keeps all six v8-v16 opt-in methods in Harry: UseEngineNetworkMovement, UseNetworkMovementAnimation, HandleNetworkMovementAnimEnd, OnEngineNetworkCorrectionApplied, OnHarryProcessMoveComplete and OnHarryReplicatedMoveComplete. It also keeps their PlayerWalking AnimEnd, correction replay, ReplicateMove, ProcessMove completion and animation-selection call sites. No HPVersus class or HPConsole is patched. An in-memory upstream-versus-result diff contains only those movement/animation hunks plus two blank lines before defaultproperties; restored Director matches upstream byte-for-byte.", "",
                  "Integration order: apply the complete validated recipe to the isolated development game; add co-op authority/camera/capture overrides in co-op-owned classes; run clean UCC make; then verify ordinary single-player damage, fatal club hit, timed cutscene/boss camera, co-op two-player damage and special states, and Versus local camera/native movement/combat. Do not reintroduce the reset behavior as a global timer workaround. Co-op damage must be authority-gated in its own override before calling the restored Harry handler. Recipe generation and compilation alone do not prove these runtime behaviors.", ""]
    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    # Windows redirected stdout may default to an ANSI code page without arrows.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch-missing", action="store_true", help="Fetch only missing upstream source Git blobs")
    parser.add_argument("--game-root", type=Path,
                        default=ROOT / "Гарри Поттер и Тайная комната",
                        help="Installed source game root; never modified")
    parser.add_argument("--upstream", type=Path, default=ROOT / ".local/upstream")
    parser.add_argument("--output", type=Path, default=ROOT / "docs/baseline/SOURCE_COMPARISON.md")
    args = parser.parse_args()
    inputs = {
        "installed": args.game_root.resolve() / "HGame/Classes",
        "v18": ROOT / "v18/v18/HGame/Classes",
        "v7": HANDOFF / "01_BASELINES/original_v7/HPVersus_dedicated_full_input_fix_20260625_v7_directmove(2).zip",
        "v16": HANDOFF / "01_BASELINES/audited_v16/HPVersus_v16_remote_bottom_align_20260905.zip",
    }
    snapshots = {name: archive_sources(path) if path.suffix == ".zip" else folder_sources(path)
                 for name, path in inputs.items()}
    trees = {ref: tree_sources(args.upstream, ref) for ref in (OLD_COMMIT, NEW_COMMIT)}
    blobs = get_blobs(args.upstream, {oid for tree in trees.values() for oid in tree.values()}, args.fetch_missing)
    for ref, tree in trees.items():
        snapshot: dict = {}
        for path, oid in tree.items():
            add_source(snapshot, path, blobs[oid])
        snapshots[ref[:7]] = snapshot
    pair_names = [("installed", "v18"), ("v7", "v16"), ("v16", "installed"),
                  ("v7", "installed"), (OLD_COMMIT[:7], "installed"),
                  (NEW_COMMIT[:7], "installed"), (OLD_COMMIT[:7], NEW_COMMIT[:7])]
    pairs = {f"{old} → {new}": compare(snapshots[old], snapshots[new]) for old, new in pair_names}
    metadata = {
        "generated_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "reproduce": f'python scripts/compare_sources.py --game-root "{display_path(args.game_root)}"',
        "inputs": {name: f"`{display_path(path)}`" for name, path in inputs.items()},
        "upstream_commits": {ref: git(args.upstream, "show", "-s", "--format=%cs %s", ref).decode("utf-8").strip() for ref in trees},
    }
    for ref in trees:
        metadata["inputs"][ref[:7]] = f"[upstream]({UPSTREAM_URL}/tree/{ref}/HGame/Classes)"
    capability = publish_capability()
    manifest_path = ROOT / ".local/source-comparison.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps({"metadata": metadata, "snapshots": snapshots,
                                       "comparisons": pairs, "publish_capability": capability},
                                      indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render_report(snapshots, pairs, metadata, capability), encoding="utf-8")
    for label, result in pairs.items():
        print(label + ": " + ", ".join(f"{key}={len(value)}" for key, value in result.items()))
    print(f"Report: {args.output}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"Source comparison failed: {exc}", file=sys.stderr)
        sys.exit(1)
