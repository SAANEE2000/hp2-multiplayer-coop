# Build warnings audit — 2026-09-20

Scope: `.local/builds/20260920-150204-881/ucc-output.log`, its `result.json`, supplied v18 source/binary, and the resulting `.local/game/System/HGame.u`. Read-only inspection; this report does not change code, assets or the build. Later co-op builds may have different warning totals.

## Result and warning accounting

The baseline build finished with **0 errors, 279 warnings**. This proves a successful compiler/package-write gate, not runtime compatibility.

| Group | Count | Assessment |
| --- | ---: | --- |
| Parameter has same name as its type | 147 | Naming ambiguity diagnostic. Do not bulk rename while stabilizing multiplayer; inspect if changing affected functions. |
| Variable has same name as its type | 23 | Same caution; e.g. local Canvas/Actor-style names. |
| Global declaration shadows inherited field/type | 71 | Potentially meaningful identity/storage difference, especially native versus script fields. Not automatically harmless. |
| Parameter shadows global field | 21 | Verify intended local parameter references. Not an asset error. |
| Cannot resolve texture literal | 10 | Concrete unresolved source object references; fix and rebuild. |
| Unknown property in defaults | 7 | These requested defaults were ignored; fix definition/assumption. |
| **Total counted by UCC** | **279** | 272 source `Warning,` lines + 7 default-property diagnostics. |

Of the 272 source warnings, 263 are HGame and nine are M212Share. There are also **three script/class-name mismatch diagnostics**, printed before class parsing and not included in the 279 warning count. Build gates should recognize these separately.

## Ten texture warnings: assets exist, literals are unresolved

- `HGame/Classes/baseWarning.uc:36`: `Texture'leftPanel'` cannot be found.
- `HGame/Classes/Menu/FEQuidPage.uc:122,123,124,145,146,147,307,308,309`: `Texture'QuidMatchBoxTexture'` cannot be found.

Both files import their PNGs with `GROUP=Icons` at line 8. Both source PNGs exist in supplied v18, installed source and local development copy. Each HGame/Textures directory had **438 files / 24,301,907 bytes** when inspected. No evidence supports the assumption that the HGame texture directory was absent.

Read-only UE package table inspection also finds these exports in both supplied and rebuilt packages:

| Object below HGame | Class | Supplied serialized size | Rebuilt serialized size |
| --- | --- | ---: | ---: |
| `Icons.leftPanel` | Engine.Texture | 4,177 | 4,177 |
| `Icons.QuidMatchBoxTexture` | Engine.Texture | 16,446 | 16,446 |

Thus these are unresolved **code references during parsing**, not missing texture exports. The first correction attempted fully qualified literals; build `20260920-152111-762` still reports all ten warnings with those qualified names. Qualification alone does not fix this M212 build path. The warnings occur during `Parsing` (log lines 972 and 1190–1198), before `Compiling` (baseWarning at 2006, FEQuidPage at 2132) and `Importing Defaults` (starting at 2142).

The narrow revised fix keeps both `#exec Texture Import` directives and their actual resource names, adds `WarningBackgroundTexture` / `QuidMatchButtonTexture` fields, and binds the qualified textures in `defaultproperties`. Executable code reads those fields. This follows the already working source pattern in `Cutscene/CutSceneManager.uc:252`, which binds the same leftPanel object in defaults. It avoids a repeated runtime load and does not substitute or remove the resources. The observed phase ordering supports an import-availability explanation; the exact native parser implementation was not inspected. A new build must verify both warning removal **and valid default object references**, followed by rendered UI checks.

Runtime exposure: baseWarning.Draw assigns the unresolved object to Background and immediately accesses Alpha/bTransparent, then draws it. FEQuidPage assigns the unresolved object to the Up/Down/Over textures of menu buttons. This can cause missing UI and Accessed None behavior; it is not cosmetic compiler noise. Actual rendered behavior was not tested by this audit.

A broad textual import-path scan initially found `Textures/DeusEx.png` missing at `Menu/FEInGamePage.uc:18`; that directive is **inside a block comment**, lines 7–32. It is not an active import failure and should not be “fixed” by inventing/replacing an asset. Import validation must account for comments.

## Seven ignored defaults

| Class | Ignored defaults | Cause / minimal correction |
| --- | --- | --- |
| HPHideSeekHiderStart | bSinglePlayerStart=False, bCoopStart=False | Extends NavigationPoint. Both properties are declared only by PlayerStart (`Engine/Classes/PlayerStart.uc:13–14`). |
| HPHideSeekHunterHuntStart | same pair | Same inheritance mismatch. |
| HPHideSeekHunterWaitStart | same pair | Same inheritance mismatch. |
| Original HPCoopGame stub | bCoopGame=True | No such member exists in supplied GameInfo. `bCoopWeaponMode` is a different property with a different purpose. |

For HideSeek, remove only the six non-existent defaults if these objects are intentionally custom NavigationPoint markers. Do not change their superclass to PlayerStart just to silence warnings: that changes spawn selection and map actor behavior. Preserve the prototype and test its own marker lookup. The new coop game should identify itself through its own class/session contract, not an absent engine switch.

## Three duplicate character declarations

Static source parsing and UCC agree:

- `Characters/HagridPlayer.uc:5` declares `class Hagrid`, also declared in `Characters/Hagrid.uc:5`.
- `Characters/HermionePlayer.uc:5` declares `class Hermione`, also declared in `Characters/Hermione.uc:5`.
- `Characters/RonPlayer.uc:5` declares `class Ron`, also declared in `Characters/Ron.uc:5`.

Both supplied and rebuilt HGame packages have Hagrid/Hermione/Ron class exports and **no HagridPlayer/HermionePlayer/RonPlayer class exports**. Therefore those experiment files do not create the advertised independent classes. Static inspection alone should not assert which duplicate defaults “won” compilation.

Smallest source correction: give each experiment its matching distinct class name, preserving the canonical NPC classes; retain inheritance/defaults initially. This is distinct from working playable-character selection: `Menu/FESkinSelectPage.uc:29–31` currently selects mesh names, so renaming these classes alone does not establish server-authoritative character selection. Alternatively explicitly exclude/archive those experiment source files from the build without deleting them; do not silently overwrite canonical NPC definitions.

## Inherited-field warnings needing targeted verification

The baseline has explicit harry redeclarations of `LastAnimFrame`, `bIsCrouching`, `bIsTurning`, `bAnimTransition`, `bFallingMount`, `GroundJumpSpeed`, `MountDelta`, and `MountBase` (`harry.uc:225,247–249,252,263–265`). Their native Actor/PlayerPawn/Pawn counterparts are separate inherited declarations according to UCC. Movement/correction and ledge auditing must establish which property each native and script path accesses. Removing declarations wholesale can change serialization and existing map/save compatibility; do not do that as warning cleanup.

Other examples include HPawn/HChar timers, enemy temporary vectors, director PlayerHarry aliases, and Quidditch target aliases. They make inherited helper changes more delicate: the same spelling may not identify the same declared field.

All nine M212Share source warnings are in `Triggers/M212CollisionTrigger.uc:12–20`. They intentionally declare three-state `ESetBool` options with the same names as inherited Actor collision booleans; Activate reads the options and applies values to another Actor. These cannot be deleted as if they were redundant inherited booleans. Renaming would require preserving editor/map property compatibility. Treat this as documented existing design debt unless an observed failure requires a narrow migration.

## Supplied versus clean-built binary

| Package | Bytes | SHA-256 |
| --- | ---: | --- |
| Supplied v18 HGame.u; installed System copy matched | 43,469,522 | `51A75482AE15223CCFE8EE941E7F5DC4F483FEEFDFBC44E8782EB002F98134A4` |
| Clean rebuilt HGame.u from audited build | 43,355,004 | `FDB84E3DE7FA9AF17221522E94B264B5E8E254E0617F70D700D007F6DDA76B24` |
| Pre-build backup in audited log directory | 43,355,004 | `1A43443795E814BF346492AADFC1AEE9F0701AF50972DA2D0445988253A37BA2` |
| Installed System/Decomp/HGame.u reference | 23,060,764 | `5E5A067042ECD60F1842CE0616CEEBE5B34974DDDBB49A125A96B5F47F6D7A3C` |

The clean output is **114,518 bytes smaller** than supplied v18. The existing `.before` file was already a prior rebuild, not the original supplied binary. Equal sizes do not imply equal bytes: this build and its preceding rebuilt copy have different hashes.

A read-only parser of the standard package name/import/export tables consumed each export table exactly through EOF. Supplied and rebuilt use package version 115; Decomp reference uses 108. The comparison is metadata inspection, not an execution or full bytecode-equivalence proof.

| Metric | Supplied v18 | Rebuilt |
| --- | ---: | ---: |
| Names | 11,371 | 11,367 |
| Imports | 2,068 | 2,070 |
| Exports | 19,623 | 19,615 |

Case-insensitive export comparison reveals **eight exports present only in supplied v18**:

- `HPVersusHarry.SpecNext` and its locals `bFoundMe`, `First`, `H`, `HSGame`, `Next`.
- `HPVersusHarry.SpectateTarget`.
- `HPVersusHarry.PlayerInput.HSGame`.

The supplied v18 source also lacks SpecNext/SpectateTarget. This is concrete evidence of a **binary/source mismatch involving HideSeek spectator behavior**. Preserve the supplied package as a reference; record this missing source behavior instead of claiming a clean rebuild preserves all prototype features. Recovering this bounded extension from the embedded source or other snapshots is separate work; it does not justify trusting the supplied binary for new source changes.

Class-count delta is one Function, one BoolProperty and six ObjectProperty exports. Texture-export counts match. Large serialized-class size differences also occur (e.g. HPConsole, HPVersusGame, HPVersusWand); those include class metadata/default serialization and cannot be attributed to missing gameplay code from size alone. The aggregate byte delta is not evidence of an absent texture folder.

## Minimal correction order

1. Bind the two imported textures through fields initialized in `defaultproperties`, replacing ten executable literals with field reads; rebuild, verify actual default object references, and check the UI.
2. Resolve the three duplicate experiment class declarations; rebuild and ensure canonical NPC classes retain their intended defaults.
3. Remove unsupported defaults or replace the nonexistent coop flag with explicit coop-session behavior; do not change marker inheritance blindly.
4. Retain and document remaining naming/shadow warnings. Address native movement field identity as part of the movement audit, with focused runtime checks.
5. Preserve supplied binary plus source manifests, explicitly track the missing spectator extension, and label source rebuild as a distinct baseline.

Suggested gate distinguishes: compile errors; unresolved resources; ignored defaults; class/file mismatches; known naming diagnostics. A single total warning count cannot identify regressions. All output remains local; no EA packages or extracted resources were published by this audit.

## Revised recipe and development-copy migration

`patches/v18-compile-cleanup.json` now describes the original-v18 to revised-output transformation. The three distinct character-class corrections are unchanged. The recipe remains ASCII JSON with byte-preserving Latin-1 replacements and whole-file input/result hashes.

The already patched development copy was moved from the qualification-only output to the revised output with the explicit local recipe `.local/patch-migrations/v18-compile-cleanup-texture-defaults-migration.json`. Its archived predecessor is `.local/patch-migrations/v18-compile-cleanup.qualification-v1.json`. These are ignored local migration artifacts, not additional recipes loaded by the normal build.

| Development source | Qualification-only input SHA-256 | Revised output SHA-256 |
| --- | --- | --- |
| `HGame/Classes/baseWarning.uc` | `f06f9630d5ba135f06e374ba096a0745b66ee6c961d8bb32d4bac040cf6b13bc` | `91a2556de095569e49fa6ad8562722794befd470c8ae4ed9aba06c81818eba2e` |
| `HGame/Classes/Menu/FEQuidPage.uc` | `8720b511e57e0a944e2b701741c885435cf1f342220f98ace43f38d62312247f` | `5f87c7e1d1120c1c8b14aeb84a2fdfe5962b9b2d65d6fe63045d67d8c36435cc` |

Before changing the development copy, the actual patch applier was exercised on a temporary marked tree: original source → previous recipe → migration → current recipe (already-applied skip) → migration (already-applied skip). All hashes and intermediate backups matched. The six recipe unit tests passed after the revision. The explicit migration then changed only the two listed development source files; the applier preserved their previous bytes under `.local/game/.patch-backups/v18-compile-cleanup-texture-defaults-migration/`.

At the time of this migration, UCC had **not yet compiled the revised texture bindings**. Subsequent build `20260920-153659-290` finished with 0 errors / 268 warnings, removing the ten unresolved texture warnings. Independent read-only decoding of both UClass tagged-defaults confirmed non-None references to the exact `Engine.Texture` exports. See [the compile-cleanup verification report](../iterations/20260920_COMPILE_CLEANUP.md) for package hash, object indices, tests and remaining runtime checks.
