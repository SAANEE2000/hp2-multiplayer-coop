# Ch1Rictusempra: original spell requirements and co-op cast review

Audit date: 2026-09-20. Static local-source/package analysis; this report is not evidence of a completed two-player playthrough. No map or active development game was changed by this audit.

## Evidence and method

`Гарри Поттер и Тайная комната/Maps/Ch1Rictusempra.unr`: 3,942,467 bytes; SHA-256 `08a827e5984df3c8bf248f599a64fad9e44e636dfe30b072647594953100161f`. Package version 79, licensee 0; 4,836 names, 280 imports, 4,156 exports. The export-table parser ended at the exact file length. Parsed property tags for all 2,135 actor exports (excluding Model, Polys and Level), with zero parse errors. All 107 detailed actor records sampled for the table/scenarios consumed their complete serialized payload.

Requirements below combine actual placed actor classes, serialized `eVulnerableToSpell` overrides and inherited source defaults. They are stronger evidence than package-name searches. There are 14 explicit vulnerability overrides: 13 spellTriggers and RoundRobin1; the remaining castable classes use inherited defaults. RoundRobin1 has Flipendo metadata but is not a normal cursor target (`RoundRobin extends Triggers`; cursor accepts Pawn/GridMover/spellTrigger only). It is not counted as an additional directly castable target.

The map imports `Skurge` and textures `skurgeWall_Rc` / `skurge_Runner_RC`, plus a `Ch2Skurge` package group. These are not Skurge gameplay actors. No placed class/default or serialized override identified a Skurge, Diffindo or Spongify target on this map. This does not certify arbitrary runtime scripts or later campaign maps.

## Required original interactions

| Spell | Placed targets and purpose | Current implementation implication |
|---|---|---|
| Rictusempra | 20 firecrabSmall and 11 orangesnail initially; stun/flip before pushing | Original projectile is whitelisted, but the new pawn startup book currently omits this learned spell. |
| Flipendo | 6 spellTriggers, 3 GridMovers, 5 bronze cauldrons, 2 GNOMEs; also the 31 enemies during their vulnerable state | Must retain original stun→push sequence and original target handlers, with shove direction from actual caster. |
| Alohomora | 7 spellTriggers and 15 chests (7 gold, 5 wood, 3 iron) | Includes EscapeDoor and knightdoor02 events, not just collectible containers. |
| Lumos | gargoyle0 and gargoyle3; two LumosTriggers and two LumosSparkles | Unsupported in HPCoopWand. Full original-map functionality cannot be claimed. Trigger names indicate secret passages; whether either is mandatory for the shortest completion route was not playtested. |

Original sources: `HGame/Classes/Enemies/firecrab.uc:340` and `orangesnail.uc:536` (Rictusempra defaults); `firecrabSmall.uc:186,201` and `orangesnail.uc:372,380` (dynamic Flipendo/Rictusempra); `Engine/Classes/GridMover.uc:266`; `HGame/Classes/Props/BronzeCauldron.uc:174`; `Enemies/GNOME.uc:1394`; `Props/chestbronze.uc:269`; `Misc/gargoyle.uc:95`. All paths in this report are relative to the installed local game unless prefixed `mod/` or `patches/`.

### Exact placed spellTriggers

| Actor | Spell | Event | Area metadata | Actor serial offset |
|---|---|---|---|---|
| spellTrigger0 | Flipendo | `PillarRoomFBlock` | `None,ColumnClimbRoom` | 2436172 |
| spellTrigger1 | Alohomora | `SecretDoor5` | `None,NewSecrets,CrabPitStairWell1Combo` | 2367511 |
| spellTrigger2 | Flipendo | `PPTopRR` | `None,PicturePuzzleRoom` | 2283252 |
| spellTrigger3 | Alohomora | `SecretDoor6` | `None,NewSecrets,ColumnClimbRoom` | 2281276 |
| spellTrigger4 | Flipendo | `PPMiddleRR` | `None,PicturePuzzleRoom` | 2368282 |
| spellTrigger5 | Flipendo | `PPBottomRR` | `None,PicturePuzzleRoom` | 2580497 |
| spellTrigger6 | Alohomora | `SecretDoor7` | `None,NewSecrets,EscapeRoute` | 2342753 |
| spellTrigger7 | Flipendo | `SilverSecretButton2` | `(not set)` | 2800582 |
| spellTrigger8 | Flipendo | `SilverSecretButton3` | `None,CageDropRoom` | 2858098 |
| spellTrigger10 | Alohomora | `knightdoor02` | `None,WeightPulleyRoom` | 3190941 |
| spellTrigger11 | Alohomora | `EscapeDoor` | `(not set)` | 3514425 |
| spellTrigger12 | Alohomora | `SnailBeanHole1` | `(not set)` | 3804593 |
| spellTrigger13 | Alohomora | `SnailBeanHole2` | `(not set)` | 3408258 |

`spellTrigger2/4/5` are front-only, with ReTriggerDelay=2.0. `spellTrigger11` has ReTriggerDelay=9.0, box collision radius=32, width=8, height=160. The once-only actors are 0/1/3/6/7/8/12/13. These flags must remain authoritative; rejection must not replace the original Trigger event chain.

### Exact remaining target actors

| Class | Count | Placed names |
|---|---:|---|
| firecrabSmall | 20 | `firecrabSmall0`, `firecrabSmall1`, `firecrabSmall10`, `firecrabSmall13`, `firecrabSmall14`, `firecrabSmall18`, `firecrabSmall19`, `firecrabSmall2`, `firecrabSmall20`, `firecrabSmall22`, `firecrabSmall23`, `firecrabSmall25`, `firecrabSmall27`, `firecrabSmall3`, `firecrabSmall4`, `firecrabSmall5`, `firecrabSmall6`, `firecrabSmall7`, `firecrabSmall8`, `firecrabSmall9` |
| orangesnail | 11 | `orangesnail0`, `orangesnail1`, `orangesnail10`, `orangesnail11`, `orangesnail2`, `orangesnail3`, `orangesnail5`, `orangesnail6`, `orangesnail7`, `orangesnail8`, `orangesnail9` |
| GridMover | 3 | `GridMover0`, `GridMover1`, `GridMover4` |
| bronzecauldron | 5 | `bronzecauldron0`, `bronzecauldron1`, `bronzecauldron2`, `bronzecauldron3`, `bronzecauldron4` |
| GNOME | 2 | `GNOME4`, `GNOME5` |
| ChestGold | 7 | `ChestGold0`, `ChestGold2`, `ChestGold3`, `ChestGold4`, `ChestGold6`, `ChestGold7`, `ChestGold8` |
| ChestWood | 5 | `ChestWood0`, `ChestWood1`, `ChestWood2`, `ChestWood3`, `ChestWood4` |
| ChestIron | 3 | `ChestIron1`, `ChestIron2`, `ChestIron3` |
| gargoyle | 2 | `gargoyle0`, `gargoyle3` |

### Lumos evidence

| Actor | Relevant metadata | Serial offset |
|---|---|---:|
| gargoyle0 | ColumnClimbRoom; inherited SPELL_Lumos | 2448274 |
| gargoyle3 | PicturePuzzleRoom; inherited SPELL_Lumos | 2712631 |
| LumosTrigger0 | Tag ColumnRoomSecret; Event ColumnRoomSecretDoor; ColumnClimbRoom | 2684501 |
| LumosTrigger1 | Event ColumnRoomSecretDoor2; WeightPulleyRoom | 2523896 |
| LumosSparkles0 | ColumnClimbRoom; area-effect distance 640 | 2358844 |
| LumosSparkles1 | No Group override; area-effect distance 640 | 2493907 |

Neither placed gargoyle overrides bInfiniteLumos. Original owner/global blockers remain: `Misc/gargoyle.uc:24–29` enables its cached PlayerHarry weapon; `Misc/LumosLight.uc:43–49` caches the global and clears its bLumosOn before caller rebinding; its TurnOn/TurnOff broadcasts apply to all actors. `Triggers/LumosTrigger.uc` caches one player for radius checks and `LumosSparkles.uc` reads that player camera. Enabling the existing spellLumos whitelist alone would not fix them.

## Rictusempra unlock provenance and startup snapshot

1. `HGame/Classes/Triggers/SpellLessonTrigger.uc:842–880`, EndLesson: the LessonShape_Rictusempra branch at 851–853 calls PlayerHarry.AddToSpellBook before EndSpellLearning and the lesson completion event.
2. `System/cutscenes/02080DADARictaEnd.int:51–55`: the completed-lesson scene changes Harry to gstate030, releases actors, then triggers ChangeLevelCh1Rictusempra.
3. `HGame/Classes/harry.uc:156` declares SpellBook[32] as travel. Basic PreBeginPlay adds only Flipendo/Lumos/Alohomora at 335–337; no defaultproperties SpellBook entries provide Rictusempra.
4. Actual Ch1 Harry0 export has no SpellBook or bNoSpellBookCheck override. The level-load CutScene1 selects Ch1RictuIntro, which contains no spell teaching. No SpellLessonTrigger is placed on this map. Its gameplay assumes the learned travel state from the preceding lesson.

Recommended first-level startup policy: prefer a server-owned snapshot of the carried canonical Harry SpellBook plus CurrentGameState before replacing/adopting that actor. Copy learned class entries to both registered pawns and deliver the same reliable owner snapshot to each client before local-context-ready. `travel` is not itself a replication rule; no SpellBook rule exists in the inspected harry replication block. A late join must receive this same session snapshot. Lessons that later change canonical SpellBook must update the session snapshot.

For an explicit fresh Ch1 test start without carried state, use a declared completed-Rictusempra-lesson preset: Flipendo, Lumos, Alohomora and Rictusempra, with the proven gstate030 stage. Log that this is a fresh stage preset. It is not a restored save or general campaign resumption. Do not call AddAllSpellsToSpellBook, set bNoSpellBookCheck, or infer learned spells from target vulnerabilities. Preserve a richer carried snapshot rather than overwriting it with the fresh preset.

## RPC and ownership review

Review snapshot SHA-256:

- `mod/HGame/Classes/HPCoopHarry.uc`: `e61107ee4bad62743994cc2aad3816aaf21075e190a0b4b80902faf8871058ea`.
- `mod/HGame/Classes/HPCoopWand.uc`: `76875d1ae68e188d0a32ffa2c63c99dddc2a2604ce9ce4b2bc0d80daeea1ce8b`.

| Finding | Evidence and impact | Narrow next action |
|---|---|---|
| Confirmed startup blocker: learned book not transferred | HPCoopHarry.PreBeginPlay:33–35 adds basic three only; HPCoopGame.AdoptStoryLeader/Login copy CurrentGameState but not SpellBook in the reviewed snapshot. Neither server nor client can correctly unlock the map’s initial enemies. | Implement the explicit learned snapshot above before ready/casting. |
| Confirmed wrong shove source for player 2 | HChar.HandleSpellFlipendo:913–923 uses cached PlayerHarry.Location. orangesnail:208, firecrabSmall:29 and GNOME:652 call it. | Apply the separately supplied narrow recipe below; keep enemy AI.PlayerHarry unchanged. |
| RPC accepts actor categories original cursor does not | HPCoopHarry:272–283 checks vulnerability and class whitelist, but no Pawn/GridMover/spellTrigger target category and no current collision/targetability check. RoundRobin1 is a real map example with Flipendo metadata despite not being an original cursor target. | Mirror original target categories and reject consumed/inactive collision targets; never use client-reported class. |
| Consumed once-only trigger can still be requested | spellTrigger.Touch:63–67 sets bCollideActors=False and bProjTarget=False without clearing vulnerability. RPC does not check these, and Trace=None is accepted. A forged request can spawn a spell at an ineligible target even if collision later prevents interaction. | Reject !bCollideActors for trigger requests; preserve bInitiallyActive/backface and original event processing. Test bProjTarget policy against original target types before making it universal. |
| Book/current vulnerability presentation is not synchronized | Actor replication:2820 onward has collision replication but no eVulnerableToSpell; enemy state code changes it on authority. RPC correctly derives the current spell on server, but a stale client cursor can display/select another spell. | Verify stun→Flipendo on the remote client; replicate target vulnerability with a narrow mechanism if observed stale. Server-derived class remains required. |
| WeaponSet call is definitely a no-op | EnsureCoopWand:131 assigns Weapon=W before WeaponSet:132. Engine.WeaponSet:496–497 immediately returns when Other.Weapon==self. | Verify original ChangedWeapon/BringUp state and third-person wand attachment in first runtime test; reorder/explicitly perform required activation if missing. No ownership failure is proven on normal creation. |
| Offset check approximates only cylinder radius | RPC:285–288 ignores CollisionWidth and local-space rotated box axes. Original cursor sends its actual hit offset. Map includes box targets and moving brushes. | Do not loosen blindly: reproduce valid rejection first, then use shape-aware bounds with modest network tolerance. |
| Facing/LOS differences need runtime confirmation | RPC tests pawn-muzzle direction against server ViewRotation and traces actor-blocking obstacles. Original cursor uses camera rays/front vector. Engine.PlayerPawn.ServerMove:811–813 updates server ViewRotation, so it is not inherently uninitialized. | Test close/overhead targets and third-person orbit on both slots; preserve server collision protection while matching legitimate cursor limits. |

The hidden-target concern is **not a confirmed blocker**: although Engine.Triggers defaults bHidden=True, Trigger.PostBeginPlay:68–76 makes TT_Shoot triggers bHidden=False with DrawType=DT_None. All original spellTriggers use TT_Shoot. Do not remove the guard based solely on the inherited class default.

Positive authority boundary: the owning pawn sends only Target/TargetOffset; server derives whitelist class and pawn-relative muzzle, checks registered player/state/cooldown/range/facing/LOS, then HPCoopWand rechecks owner, weapon, spellbook, vulnerability and muzzle segment. Gameplay original spells use ROLE_None after server spawn; the companion visual carries no hit logic. No camera or WeaponLoc is consulted by CastCoopSpell.

Normal wand ownership startup: Spawn(HPCoopWand,self) sets the intended Owner; Pawn.AddInventory:896 sets it again. HPCoopWand.PostBeginPlay and Tick bind PlayerHarry from Owner, allowing delayed client Owner replication to recover. Skipping baseWand Pre/Post removes its unowned sword effect and global LumosLight creation. Engine Weapon/Inventory PostBeginPlay do not cache a global Harry. The early existing-Weapon return assumes the replicated/existing Owner is correct; authority cast rejects mismatches.

## baseSpell early callback check

There is no baseSpell.PreBeginPlay override. It inherits Actor.PreBeginPlay:3517–3525 through Projectile; this checks relevance/software rendering, not PlayerHarry. baseSpell.PostBeginPlay:60–67 calls Super, reads Level.PlayerHarryActor into its own field, and initializes CurrentDir. It does not write the canonical pawn, spawn Lumos, or call a target handler. Alohomora/Skurge/Spongify PostBeginPlay only adjust CurrentDir; the other supported subclasses have no extra startup global reads. Actor.PostBeginPlay particle reparenting is gated by bDrawColPFXFirst, false for these classes.

HPCoopWand:271–281 passes Caster as Spawn owner, then sets Instigator and PlayerHarry before InitSpell. Original InitSpell:38–57 assigns target/offset/wand, creates the original fly effect, and invokes OnSpellInit. Rictusempra’s first PlayerHarry use is OnSpellInit:21 and therefore uses the rebound caster. No supported-class script startup mutation of the wrong player was found. This finding does not certify native callbacks before Spawn returns: immediate-overlap/close-wall behavior still needs runtime testing. The muzzle segment trace has zero extent while spell collision radius/height are 2, so a very tight edge case is possible.

## Narrow Flipendo caster recipe

`patches/coop-spell-caster.json` replaces only HChar.HandleSpellFlipendo. Source SHA-256 `8da013b92c445bd5a675f1bcc3609a47319bb9c318ed75613c01397a9c657fad` matches installed/v18 and upstream commits 7105bae78ee2e7c5a3b4d2dff65e1ea7cc903e8b and d052c5bdb3ed2e232fa0f71d0189880d585b295d. Result SHA-256 `5772ddde74bb6d357fffad082322c270ee33ad2e8ad7e3d6558b734aec4d43e0`.

The local PushSource starts as original PlayerHarry. On authority in HPCoopGame, a nondeleted original spell may select its registered nondeleted Instigator, or registered Owner fallback. All other cases preserve original behavior. Super callback, bFlipPushable, PHYS_Falling, force values and return remain unchanged. No AI context is reassigned. This is a caster correction, not a finished multi-player enemy AI implementation.

Validated with the actual scripts/apply_patches.py apply_recipe on an isolated ignored fixture: exact output SHA, second-apply idempotence, inverse replacement byte identity, rejection of source drift without modifying that fixture, and unchanged installed source. No active game tree was patched and no UCC build was run by this audit agent. Root must include this recipe in the next build and verify first-player/second-player shove directions plus standalone regression.

Known remaining original-context gap: firecrab.pushDirection at Enemies/firecrab.uc:146–180 still uses canonical PlayerHarry for later ledge decisions. Its direction may differ from the actual second caster after the immediate shove. Retained intentionally outside this recipe.
