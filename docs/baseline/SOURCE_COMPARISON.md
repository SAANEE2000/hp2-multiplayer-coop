# Source comparison and publish capability

Generated UTC: 2026-09-20T12:13:42+00:00. Reproduce with `python scripts/compare_sources.py --game-root "Гарри Поттер и Тайная комната"`.

The supplied archives, v18 and installed source directories must exist. An existing clone of the upstream Scaling-Patch branch belongs at `.local/upstream` (override with `--upstream`); both commits below must be fetched. If source blobs are missing from a partial clone, add `--fetch-missing` once. Subsequent runs are offline. The fetch uses explicit source object IDs and does not update branches or check out files.

This report contains source names, counts and source-derived findings only. Full upstream blobs remain in ignored `.local/upstream`; full manifests remain in ignored `.local/source-comparison.json`. No retail binaries/assets or decompiled source are copied into tracked paths.

## Inputs and method

Scope is HGame `Classes/**/*.uc`. Directory and archive names are compared case-insensitively. SHA-256 identifies exact equality; a second hash ignores whitespace outside quoted literals and a UTF-8 BOM. Comments are retained. Thus `changed` means a source change beyond formatting, not proof of a behavioral change. UTF-8/legacy encodings are not silently transcoded.

| Snapshot | Classes | Source |
| --- | ---: | --- |
| installed | 874 | `Гарри Поттер и Тайная комната/HGame/Classes` |
| v18 | 874 | `v18/v18/HGame/Classes` |
| v7 | 856 | `HPVersus_Local_Codex_Handoff_20260920/01_BASELINES/original_v7/HPVersus_dedicated_full_input_fix_20260625_v7_directmove(2).zip` |
| v16 | 857 | `HPVersus_Local_Codex_Handoff_20260920/01_BASELINES/audited_v16/HPVersus_v16_remote_bottom_align_20260905.zip` |
| 7105bae | 846 | [upstream](https://github.com/metallicafan212/HP2UScriptDecompile/tree/7105bae78ee2e7c5a3b4d2dff65e1ea7cc903e8b/HGame/Classes) |
| d052c5b | 846 | [upstream](https://github.com/metallicafan212/HP2UScriptDecompile/tree/d052c5bdb3ed2e232fa0f71d0189880d585b295d/HGame/Classes) |

Upstream commit dates are commit metadata, not release or verified-build dates:

- [7105bae78ee2e7c5a3b4d2dff65e1ea7cc903e8b](https://github.com/metallicafan212/HP2UScriptDecompile/commit/7105bae78ee2e7c5a3b4d2dff65e1ea7cc903e8b): 2025-11-26 Updated localization provided by DivingDeep.
- [d052c5bdb3ed2e232fa0f71d0189880d585b295d](https://github.com/metallicafan212/HP2UScriptDecompile/commit/d052c5bdb3ed2e232fa0f71d0189880d585b295d): 2026-07-22 Added a bool for HP1 style chests.

## Comparison counts

Each row is old → new; additions/removals are relative to the old source set.

| Comparison | Added | Removed | Changed | Whitespace only | Byte-identical |
| --- | ---: | ---: | ---: | ---: | ---: |
| installed → v18 | 0 | 0 | 0 | 0 | 874 |
| v7 → v16 | 1 | 0 | 5 | 0 | 851 |
| v16 → installed | 17 | 0 | 11 | 0 | 846 |
| v7 → installed | 18 | 0 | 11 | 0 | 845 |
| 7105bae → installed | 28 | 0 | 3 | 0 | 843 |
| d052c5b → installed | 28 | 0 | 4 | 0 | 842 |
| 7105bae → d052c5b | 0 | 0 | 1 | 0 | 845 |

## Changed source classes

All paths below are relative to `HGame/Classes` (or the archive's `Classes`). Formatting-only files are counted above and omitted below; their names/hashes remain in the local manifest.

### v7 → v16

Added (1):

- `HPVersusRemoteAnimChannel.uc`

Changed (5):

- `harry.uc`
- `HPVersusHarry.uc`
- `HPVersusSpell.uc`
- `HPVersusWand.uc`
- `Internal/HPConsole.uc`


### v16 → installed

Added (17):

- `Characters/HagridPlayer.uc`
- `Characters/HermionePlayer.uc`
- `Characters/RonPlayer.uc`
- `HPHideSeek/HPHideSeekGame.uc`
- `HPHideSeek/HPHideSeekGRI.uc`
- `HPHideSeek/HPHideSeekHiderStart.uc`
- `HPHideSeek/HPHideSeekHunterHuntStart.uc`
- `HPHideSeek/HPHideSeekHunterWaitStart.uc`
- `HPVersusAlohomora.uc`
- `HPVersusExpelliarmus.uc`
- `HPVersusFlipendo.uc`
- `HPVersusHealthPickup.uc`
- `HPVersusMimblewimble.uc`
- `HPVersusRictusempra.uc`
- `HPVersusSpeedPickup.uc`
- `HPVersusSpongify.uc`
- `Menu/FESkinSelectPage.uc`

Changed (11):

- `HPVersusCamera.uc`
- `HPVersusDirector.uc`
- `HPVersusGame.uc`
- `HPVersusGRI.uc`
- `HPVersusHarry.uc`
- `HPVersusPRI.uc`
- `HPVersusRemoteAnimChannel.uc`
- `HPVersusSpell.uc`
- `HPVersusStart.uc`
- `HPVersusWand.uc`
- `Internal/HPConsole.uc`


### v7 → installed

Added (18):

- `Characters/HagridPlayer.uc`
- `Characters/HermionePlayer.uc`
- `Characters/RonPlayer.uc`
- `HPHideSeek/HPHideSeekGame.uc`
- `HPHideSeek/HPHideSeekGRI.uc`
- `HPHideSeek/HPHideSeekHiderStart.uc`
- `HPHideSeek/HPHideSeekHunterHuntStart.uc`
- `HPHideSeek/HPHideSeekHunterWaitStart.uc`
- `HPVersusAlohomora.uc`
- `HPVersusExpelliarmus.uc`
- `HPVersusFlipendo.uc`
- `HPVersusHealthPickup.uc`
- `HPVersusMimblewimble.uc`
- `HPVersusRemoteAnimChannel.uc`
- `HPVersusRictusempra.uc`
- `HPVersusSpeedPickup.uc`
- `HPVersusSpongify.uc`
- `Menu/FESkinSelectPage.uc`

Changed (11):

- `harry.uc`
- `HPVersusCamera.uc`
- `HPVersusDirector.uc`
- `HPVersusGame.uc`
- `HPVersusGRI.uc`
- `HPVersusHarry.uc`
- `HPVersusPRI.uc`
- `HPVersusSpell.uc`
- `HPVersusStart.uc`
- `HPVersusWand.uc`
- `Internal/HPConsole.uc`


### 7105bae → installed

Added (28):

- `Characters/HagridPlayer.uc`
- `Characters/HermionePlayer.uc`
- `Characters/RonPlayer.uc`
- `HPCoopGame.uc`
- `HPHideSeek/HPHideSeekGame.uc`
- `HPHideSeek/HPHideSeekGRI.uc`
- `HPHideSeek/HPHideSeekHiderStart.uc`
- `HPHideSeek/HPHideSeekHunterHuntStart.uc`
- `HPHideSeek/HPHideSeekHunterWaitStart.uc`
- `HPVersusAlohomora.uc`
- `HPVersusCamera.uc`
- `HPVersusDirector.uc`
- `HPVersusExpelliarmus.uc`
- `HPVersusFlipendo.uc`
- `HPVersusGame.uc`
- `HPVersusGRI.uc`
- `HPVersusHarry.uc`
- `HPVersusHealthPickup.uc`
- `HPVersusMimblewimble.uc`
- `HPVersusPRI.uc`
- `HPVersusRemoteAnimChannel.uc`
- `HPVersusRictusempra.uc`
- `HPVersusSpeedPickup.uc`
- `HPVersusSpell.uc`
- `HPVersusSpongify.uc`
- `HPVersusStart.uc`
- `HPVersusWand.uc`
- `Menu/FESkinSelectPage.uc`

Changed (3):

- `Director.uc`
- `harry.uc`
- `Internal/HPConsole.uc`


### d052c5b → installed

Added (28):

- `Characters/HagridPlayer.uc`
- `Characters/HermionePlayer.uc`
- `Characters/RonPlayer.uc`
- `HPCoopGame.uc`
- `HPHideSeek/HPHideSeekGame.uc`
- `HPHideSeek/HPHideSeekGRI.uc`
- `HPHideSeek/HPHideSeekHiderStart.uc`
- `HPHideSeek/HPHideSeekHunterHuntStart.uc`
- `HPHideSeek/HPHideSeekHunterWaitStart.uc`
- `HPVersusAlohomora.uc`
- `HPVersusCamera.uc`
- `HPVersusDirector.uc`
- `HPVersusExpelliarmus.uc`
- `HPVersusFlipendo.uc`
- `HPVersusGame.uc`
- `HPVersusGRI.uc`
- `HPVersusHarry.uc`
- `HPVersusHealthPickup.uc`
- `HPVersusMimblewimble.uc`
- `HPVersusPRI.uc`
- `HPVersusRemoteAnimChannel.uc`
- `HPVersusRictusempra.uc`
- `HPVersusSpeedPickup.uc`
- `HPVersusSpell.uc`
- `HPVersusSpongify.uc`
- `HPVersusStart.uc`
- `HPVersusWand.uc`
- `Menu/FESkinSelectPage.uc`

Changed (4):

- `Director.uc`
- `harry.uc`
- `Internal/HPConsole.uc`
- `Props/chestbronze.uc`


### 7105bae → d052c5b

Changed (1):

- `Props/chestbronze.uc`


## Findings and integration boundaries

- Installed HGame source equals the supplied v18 source byte-for-byte: **YES**. This establishes source snapshot identity only, not identity with compiled HGame.u or successful UCC compilation.
- Audited v16 contains multiplayer movement/camera/ownership corrections. Its original baseWand, baseSpell, SpellCursor, BaseCam and BaseCamTarget remain unchanged in v18; campaign compatibility is not established by Versus fixes. See `docs/audits/SPELL_CONTEXT_AUDIT.md` for exact source lines.
- v18 is a development candidate with additional combat, character and hide/seek work; a `version=16` log marker does not identify its actual source. Preserve it independently while bringing co-op up from a clean build.
- Against historical upstream 7105bae, the supplied v18 changes exactly three existing HGame classes: Director, harry and Internal/HPConsole. All other differences are added classes; the original spell/camera/AI source trees are largely untouched.
- Supplied v18 Director.OnPlayerPossessed (`Director.uc:105–135`) clears capture, disables death, sets Health=100 and forces the standard camera. Supplied `harry.uc:2288` replaces original Harry damage processing with an authority gate plus Super.TakeDamage (it is not strictly a no-op); `KillHarryWithClub:1602` does nothing; `KillHarry:1565` adds broad death guards. These are inherited campaign/single-player regressions to reconcile against upstream, not neutral multiplayer hooks. The input-routing work in `Internal/HPConsole.uc:580` onward also deserves preservation and review rather than wholesale replacement.
- HGame differs between 7105bae and d052c5b only in `Props/chestbronze.uc`: the newer upstream adds the optional `bSpawnAllAtOnce` property and skips per-object ejection sleeps when enabled, alongside formatting/comment cleanup. It is an independent chest option, not a networking fix. Installed/v18 retains the older chest implementation.
- The supplied `HPCoopGame.uc` is already present among additions relative to upstream, including in the v7 snapshot. Its existence is not evidence of a working campaign architecture; it is a minimal GameInfo/PostLogin experiment. A new co-op foundation must replace that experiment deliberately rather than create a duplicate class declaration.
- Upstream comparison is against the exact requested historical commits. Upstream fixes and local multiplayer changes must be merged by class/function; do not replace the installed tree wholesale or treat every upstream difference as a multiplayer regression.
- Whitespace equivalence is a review filter, not an UnrealScript parser or test. This script does not compile, run gameplay, prove authority, or establish two-PC compatibility.

## Safe public-publish capability

- GitHub CLI on PATH: **False**. Present at a checked standard install path: **False**.
- Git credential helper configured: **True**; sanitized type(s): **manager**. Git Credential Manager executable present: **True**.
- GH_TOKEN/GITHUB_TOKEN environment variables present: **False / False**. Values were not printed, stored, or queried through credential fill.
- A configured credential helper does not prove GitHub authentication, push authorization or repository-creation permission. No auth or remote write was attempted by this comparison task.
- Parent task reports an authenticated GitHub connector as `SAANEE2000`, but no repository-creation tool. Connector authentication and Git CLI credentials are separate capabilities.
- Safe route: create the requested public repository through an authorized UI/API capability or available GitHub CLI, then push only the allowlisted mod/patch/script/config/doc/test tree after checking staged/tracked paths. Keep `.local`, supplied snapshots, full decompile, binaries and assets excluded. Do not assume the credential helper can create a repository; authentication must be confirmed by a supported operation without exposing credentials.

## Narrow legacy-gameplay restoration recipe

Recipe: `patches/restore-legacy-gameplay.json`. This comparison task generated and validated the recipe in memory; it did **not** apply it to gameplay sources. The complete file is ASCII JSON with byte-preserving Latin-1 strings. Encode each decoded `old`/`new` value as Latin-1 before exact byte replacement. Do not normalize newlines or decode original source as UTF-8 when applying these replacements.

Original means upstream 7105bae. These two upstream files are also unchanged at d052c5b. Line ranges are diagnostic only; the patch requires whole-file input SHA and a unique exact old byte sequence, then validates the complete expected result SHA before writing a development copy.

| File / global function | v18 lines | Original lines | Action |
| --- | --- | --- | --- |
| HGame/Classes/harry.uc / KillHarry | 1565–1600 | 1565–1583 | Restore original function |
| HGame/Classes/harry.uc / KillHarryWithClub | 1602–1608 | 1585–1598 | Restore original function |
| HGame/Classes/harry.uc / TakeDamage | 2288–2294 | 2278–2450 | Restore original function |
| HGame/Classes/harry.uc / Timer | 4991–5012 | 5091–5094 | Restore original function |
| HGame/Classes/harry.uc / PostNetBeginPlay | 6214–6241 | absent | Remove added override; inherit original behavior |
| HGame/Classes/harry.uc / Tick | 6243–6259 | absent | Remove added override; inherit original behavior |
| HGame/Classes/Director.uc / OnPlayerPossessed | 105–135 | 105–109 | Restore original function |

Whole-file preconditions and expected results:

- `HGame/Classes/harry.uc` input: `c4dfe134fdc5da24d691296cc65f60999cb5b8fa60e1e6dacefa485fef09f6c3`; result: `09d939227a6e3b4844990d0206b322ac2fd2738d58425df0d7e5274062a48ef0`.
- `HGame/Classes/Director.uc` input: `2cca4b30a4f03668db45fb73f9f24d5b100442d800c7906a5b81fa6ed7a8a3a8`; result: `d919f313740e9182f8afef17d74739adc58c2cde63e705ee11fc75db5cdade41`.

Why these seven hunks belong together:

- KillHarry regains the original Director/boss/death-state flow. KillHarryWithClub regains its club-death flag and rotation. TakeDamage regains Harry-specific status, difficulty, potion, knockback, hurt/boss notification and death behavior instead of delegating all processing to PlayerPawn.
- Timer regains only SleepyAnimTimerSub. v18 had added Super.Timer, an unconditional Health=100 / bAllowHarryToDie=False reset, and a client branch forcing input, walking physics and standard camera. Fixing TakeDamage while retaining this Timer would silently undo damage and special states later.
- Added PostNetBeginPlay uses Role<Authority, which includes remote simulated pawns; it clears capture and redirects camera to whichever pawn executes. Removing the global override preserves subclass-owned local bootstrap and the existing Versus override.
- Added global Tick forces standard camera whenever the camera is in any other mode, including cutscene/boss modes. Removing it restores inherited behavior; existing state-specific Tick methods and Versus Tick remain untouched.
- Director.OnPlayerPossessed regains its original console binding only. Campaign possession must not reset health, disable death, clear capture, or force camera mode globally. A dedicated-safe/local-context Director override still belongs in the new co-op foundation.

The recipe deliberately keeps all six v8-v16 opt-in methods in Harry: UseEngineNetworkMovement, UseNetworkMovementAnimation, HandleNetworkMovementAnimEnd, OnEngineNetworkCorrectionApplied, OnHarryProcessMoveComplete and OnHarryReplicatedMoveComplete. It also keeps their PlayerWalking AnimEnd, correction replay, ReplicateMove, ProcessMove completion and animation-selection call sites. No HPVersus class or HPConsole is patched. An in-memory upstream-versus-result diff contains only those movement/animation hunks plus two blank lines before defaultproperties; restored Director matches upstream byte-for-byte.

Integration order: apply the complete validated recipe to the isolated development game; add co-op authority/camera/capture overrides in co-op-owned classes; run clean UCC make; then verify ordinary single-player damage, fatal club hit, timed cutscene/boss camera, co-op two-player damage and special states, and Versus local camera/native movement/combat. Do not reintroduce the reset behavior as a global timer workaround. Co-op damage must be authority-gated in its own override before calling the restored Harry handler. Recipe generation and compilation alone do not prove these runtime behaviors.
