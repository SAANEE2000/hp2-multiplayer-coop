# Original spells and owning-client context audit

Date: 2026-09-20. Scope: read-only analysis of installed M212/HGame, the v18 source snapshot, audited v16 archive and handoff reports. No gameplay source changed by this audit. Findings are source evidence, not a successful runtime or two-PC test.

## Source roots and comparison

Paths below are relative to the workspace. `G` means `Гарри Поттер и Тайная комната/HGame/Classes`; `E` means `Гарри Поттер и Тайная комната/Engine/Classes`; `V18` means `v18/v18/HGame/Classes`.

Audited v16 archive: `HPVersus_Local_Codex_Handoff_20260920/01_BASELINES/audited_v16/HPVersus_v16_remote_bottom_align_20260905.zip`, entries under `Classes/`. Read directly using ZipFile/StreamReader; archive untouched.

Whitespace-insensitive comparisons prove the following source files are identical across installed game, v18 and audited v16: `baseWand.uc`, `baseSpell.uc`, `SpellCursor.uc`, `BaseCam.uc`, `BaseCamTarget.uc`. Thus the v11-v16 work fixed these problems inside Versus subclasses; it did not make the original campaign spell chain multiplayer-compatible.

Installed `HPVersusHarry.uc`, `HPVersusWand.uc`, `HPVersusSpell.uc` match v18 ignoring whitespace and differ from audited v16. The v18 handoff explicitly calls v18 the newest candidate, not a fully verified successor. `version=16` log strings do not prove v16 source.

Relevant handoff evidence: `04_REPORTS/Iteration_11_Report_RU.md` documents owner-scoped wand/cursor and server spawn; `04_REPORTS/Architecture_Audit_RU.md` documents camera bootstrap races; `02_LATEST_USER_SNAPSHOT_v18/README_V18_STATUS_RU.md` documents candidate status and missing source/binary validation.

## Original gameplay chain to retain

1. `Гарри Поттер и Тайная комната/System/DefUser.ini:55`: LMB is `AltFire` plus special-mode input buttons. Replacing only `Fire()` misses ordinary campaign input.
2. `G/harry.uc:3464`, `3483`, `3706`: `AltFire` enters aiming. `G/cHarryAnimChannel.uc:50–52`, `133`, `158`, `196`: the animation channel calls the owning Harry's virtual `Cast()`.
3. `G/harry.uc:3319`, `3429–3445`: cast branches distinguish forced boss spell, duel spell, sword and ordinary cursor lock. Ordinary cast passes `SpellCursor.aCurrentTarget` AND `vTargetOffset` to the wand. Preserve these branches; first ordinary-map implementation may explicitly leave special modes unverified.
4. `G/baseWand.uc:251–271`: spell selection already checks the wand Owner's spellbook. `435–470`: `CastSpell` selects an original spell class, spawns it, adds wand bookkeeping and calls `InitSpell(Owner, target, offset, charge, wand)`.
5. `G/baseSpell.uc:38–57`: `InitSpell` sets Owner, target, offset, wand and charge, then invokes the original virtual `OnSpellInit`. It does NOT explicitly set `Instigator`.
6. `G/baseSpell.uc:159–224`: collision rejects the owner, calls the original spell-specific `OnSpellHitHarry` / `OnSpellHitHPawn`, then `HPawn(Other).OnSpellHit` and effects. `G/HPawn.uc:1112–1118` emits the object's configured event when `bSpellCausesTrigger`.
7. `G/Triggers/spellTrigger.uc:17–50`, `53–65`: relevance depends on original `SpellType`; its own `Touch` calls Engine Trigger behavior. `E/Trigger.uc:385–400` calls `Activate(Other, Other.Instigator)`, which dispatches the actual `Trigger` event at `316–330`. `baseSpell.ProcessTouch`'s spellTrigger branch only makes effects; it is NOT the event dispatcher. Do not add a second unconditional trigger dispatch to the spell.

Original spell dispatches that must remain functional:

| Original class under G/Spells | Handler call line | Behavior entry on target |
| --- | ---: | --- |
| spellFlipendo.uc | 25 | HandleSpellFlipendo |
| spellAlohomora.uc | 19 | HandleSpellAlohomora |
| spellLumos.uc | 9 | HandleSpellLumos |
| spellSkurge.uc | 19 | HandleSpellSkurge |
| spellRictusempra.uc | 31 | HandleSpellRictusempra |
| spellDiffindo.uc | 13 | HandleSpellDiffindo |
| spellSpongify.uc | 19 | HandleSpellSpongify |

Replacing these with `HPVersusSpell` is incorrect: `V18/HPVersusSpell.uc:195–202` deliberately ignores ordinary non-Harry HPawns, and Versus spell selection/spawn is a different whitelist (`HPVersusHarry.uc:729–750`, `HPVersusWand.uc:350–357`).

## Context classification and exact defects

`LOCAL_PLAYER_CONTEXT` below includes per-player wand/status ownership on authority as well as the actual local viewport presentation. It never means “choose the first Harry.” `GLOBAL_STORY_CONTEXT` remains canonical server StoryLeader state. `AI_TARGET_CONTEXT` is a live actor chosen by authoritative combat logic.

| Location | Classification | Finding / required boundary |
| --- | --- | --- |
| G/SpellCursor.uc:51–61 | LOCAL_PLAYER_CONTEXT | PreBeginPlay caches Level.PlayerHarryActor and spawns an unowned gesture; caller does not supply owner in harry.PreBeginPlay:328. Bootstrap may cache legacy Entry Harry. Spawn with pawn Owner and explicitly bind cursor.PlayerHarry before its active tick. |
| G/SpellCursor.uc:193–206, 214, 232–248, 311–327 | LOCAL_PLAYER_CONTEXT | Target acquisition uses that player's camera, spellbook and wand. It intentionally ignores all Harry actors. Preserve this for cooperative puzzle aiming; PvP targeting is a separate policy. Offset and front-only trigger checks cannot be discarded by server request validation. |
| G/baseWand.uc:40–44 | LOCAL_PLAYER_CONTEXT | Wand caches global Harry despite having an Owner. Bind from Owner; rebind after inventory ownership changes. A late assignment alone cannot undo side effects already performed in spawned LumosLight.PreBeginPlay. |
| G/baseWand.uc:473–486, 498–503, 573–575 | LOCAL_PLAYER_CONTEXT / target-specific | Global cache affects difficulty adjustment, player view effects and Lumos query, not only debug logging. Distinguish caster and hit player when applying effects. |
| G/baseWand.uc:513–570 | LOCAL_PLAYER_CONTEXT supplied to authoritative simulation | Projectile muzzle reads render-derived WeaponLoc/WeaponRot; aim reads harry(Owner).Cam or SpellCursor. Dedicated has no owning client's render bone/camera. Owner rebinding alone is insufficient. |
| G/baseSpell.uc:60–65 | MIXED: caster, AI target, presentation | One cached PlayerHarry is overloaded by subclasses. For a player campaign spell, derive caster from Owner/Instigator. Enemy projectile uses may refer to intended victim. Do not globally replace this cache with Owner for every spell class. |
| G/baseSpell.uc:281–287 | LOCAL_PLAYER_CONTEXT / hit actor | Duel hit effect lifetime reads cached Harry and its DuelOpponent instead of actual ActorHit. Use the actual target when adapting this branch. |
| G/baseSpell.uc:351–375 | caster ownership | Reflection changes Owner and SpellWand but not explicitly Instigator or PlayerHarry. Any multiplayer owner binding must also cover reflection and kill/trigger attribution. |
| G/Misc/gargoyle.uc:24–26 | LOCAL_PLAYER_CONTEXT / caster | HandleSpellLumos turns on baseWand(PlayerHarry.Weapon), so partner's spell can light StoryLeader's wand. Resolve the casting Harry from non-null spell.Owner/Instigator; retain deliberate fallback for scripted calls that supply no spell. |
| G/Misc/LumosLight.uc:41–49, 118–124, 152–156 | LOCAL_PLAYER_CONTEXT | PreBeginPlay caches global Harry and immediately resets its bLumosOn. Light is spawned with wand Owner, so resolve through baseWand(Owner).Owner before writes. Each player needs own light/state. |
| G/Spells/spellAcidSpit.uc:80–89 | AI_TARGET_CONTEXT / actual victim | Checks Other.IsA('harry') but damages PlayerHarry. With two players, touching partner damages cached leader. Apply damage to the hit Harry. |
| G/Spells/AragogSpellAttack.uc:56, 88–97 | AI_TARGET_CONTEXT / actual victim | Distance/aim can use resolved target; ProcessTouch damage at 95 must use actual touched victim. |
| G/Spells/spellFireSmall.uc:44, 78–79, 109–114 | AI_TARGET_CONTEXT | Cached Harry drives homing/splash placement; direct damage at 51 already uses aHit. Target resolver should set intended enemy projectile target without rewriting hit victim. |
| G/Spells/spellFireLarge.uc:84–90, 142–143, 167, 182–192 | AI_TARGET_CONTEXT and local shake | Projectile targeting uses Harry cache, while ShakeView is presentation. These require separate treatment. |
| G/harry.uc:458–466 | LOCAL_PLAYER_CONTEXT | First BaseCam found is reused. A remote pawn must never initialize/reassign the local camera. |
| G/BaseCam.uc:473–498 | LOCAL_PLAYER_CONTEXT | PostBeginPlay uses global Harry, creates CamTarget and sets camera Owner to CamTarget. A simple harry(Owner) replacement would be wrong for BaseCam. Bind a dedicated player-context field; preserve the camera/target ownership relationship. |
| G/BaseCamTarget.uc:5; G/HPawn.uc:92–99 | LOCAL_PLAYER_CONTEXT | CamTarget extends HiddenHPawn and inherits HPawn's global PlayerHarry cache. Set CamTarget.PlayerHarry as well as CamTarget.Cam and attachment. |
| G/BaseCam.uc:644,677; 1068–1092; 1265 onward | LOCAL_PLAYER_CONTEXT | Mouse input, cutscene camera, FOV, fades and shake depend on local owner. Standard-camera rebinding must not override active cutscene camera every tick. |
| G/HUD/HPHud.uc:34, 208, 278–286, 340 | LOCAL_PLAYER_CONTEXT | Main HUD already uses Owner and harry(Owner).managerStatus. Preserve this. Its manager dependencies still need context repair. |
| G/harry.uc:329–339 | LOCAL_PLAYER_CONTEXT / authoritative per-player status | Creates a separate StatusManager and sets its PlayerHarry, but also dereferences Player.Console during PreBeginPlay. Dedicated/nonlocal creation requires a local-viewport gate for menu bootstrap. |
| G/HUD/HudItemManager.uc:38–44 | LOCAL_PLAYER_CONTEXT | CheckHUDReferences reassigns PlayerHarry from global whenever either player OR HUD is absent. This can overwrite a correct server/per-player context merely because no HUD exists. |
| G/HUD/StatusManager.uc:143–165 | LOCAL_PLAYER_CONTEXT | StatusGroup spawned without owner; smParent assigned after Spawn. Group's own Pre/PostBeginPlay already ran before this assignment. Bind group.PlayerHarry/HUD explicitly after creation or add owner-aware bootstrap. |
| G/StatusGroups/StatusGroup.uc:683–696 | LOCAL_PLAYER_CONTEXT | Separately caches global Harry then its HUD. Correct StatusManager.PlayerHarry does not fix this second cache. |
| G/StatusItems/StatusItem.uc:183–191; G/StatusGroups/StatusGroup.uc:352–366 | LOCAL_PLAYER_CONTEXT | Font and pickup projection use sgParent.smParent.PlayerHarry and camera. These references are correct only after manager/group chain has a valid owning client. |
| G/HUD/VendorManager.uc:156–168,192–194,345,474 | MIXED | UI/camera/console is local; purchases and story availability are authoritative. Cannot classify this entire class as one global context or run unchanged on dedicated. |
| G/HUD/ChallengeScoreManager.uc:68–77,412–438,770–772 | MIXED | Local HUD registration and shared challenge scoring/time-up event live together. Shared event must execute once server-side, then local presentation on each client. |
| G/StatusGroups/StatusGroupWizardCards.uc:274–305 | GLOBAL_STORY_CONTEXT | Card availability depends on CurrentGameState via manager's Harry. Shared progression should come from StoryLeader/shared state, even when rendering belongs to each local player. |
| G/Internal/HPConsole.uc:465,630–639 | LOCAL_PLAYER_CONTEXT | Viewport.Actor binding is useful. Compatibility alias updates belong only on owning client, never as a server player registry. |

This is a subsystem audit, not a claim that every global usage in the whole campaign has been classified. Story/cutscene/AI and special modes need their companion audits.

## What v16 already fixed and what cannot be inherited unchanged

Audited v16 `Classes/HPVersusHarry.uc` had `IsLocalViewportPlayer` at 162, camera bootstrap at 636, server cursor replication suppression at 788, nonlocal cursor disabling at 801, local spell-object rebinding at 822 and virtual Cast/server request at 2075/2144. It provides the right separation of owning viewport from remote proxy. v18 preserves that foundation but expands combat and hide/seek behavior.

Current examples worth reusing as small helpers:

- `V18/HPVersusWand.uc:20–36` skips unsafe original Lumos startup for Versus and binds wand from Owner. Co-op must instead support owner-scoped Lumos, not drop it.
- `V18/HPVersusHarry.uc:791–845` creates authoritative separate inventory wand and sets Owner/Instigator; `855–935` suppresses server cursor replication and rebinds local cursor/player/camera.
- `V18/HPVersusSpell.uc:31–89` creates a simulated local fly effect following a replicated projectile; `92–118` cleans it up and separates client cleanup from authority wand bookkeeping.
- `V18/HPVersusCamera.uc:32–34` correctly requires actual Viewport, not bIsPlayer or merely Role<Authority.

Directly deriving campaign behavior from all of HPVersusHarry remains unsafe:

- `V18/HPVersusHarry.uc:1054–1083` clears capture and forces walking/physics during setup.
- `V18/HPVersusHarry.uc:1852–1859` clears `bKeepStationary`/`bIsCaptured` and applies standard camera every input tick. This breaks canonical campaign input locks/cutscenes.
- `V18/HPVersusCamera.uc:67–85,104–115` changes the local alias, target attachment and camera mode but does not explicitly set CamTarget.PlayerHarry.
- `V18/HPVersusHarry.uc:675–687` destroys every non-Versus Harry on local client. Do not carry this broad deletion into a campaign that has scripted/transformed Harry actors without a narrower, proven bootstrap rule.
- `V18/HPVersusHarry.uc:1084–1093` resets health through both status and Health. Rejoining/travel setup cannot blindly reset campaign health/progression.

## Authority and presentation gaps

Original baseWand and baseSpell declare no replication block for original cast request/target/charge. Their ordinary script methods are not a network protocol. `RemoteRole=ROLE_SimulatedProxy` on a projectile does not transfer `InitSpell` execution or its custom target/charge/FX references to clients.

`G/Spells/spellRictusempra.uc:40–55` has a non-simulated StateFlying Tick and `DrawType=DT_None` at 78. Other ordinary campaign spells follow the same pattern. Server collision may work while clients lack a following visible fly effect. Do not solve this by allowing clients to run authoritative spell handlers. Introduce a visual companion or opt-in simulated base hook that follows replicated projectile position, creates one local effect, and has a bounded destruction path. Existing authority fly ParticleFX must not also replicate into a stationary duplicate.

Original `baseSpell.HitWall` is simulated (`136`) but calls non-simulated gameplay/effect hooks and destroys the actor. For co-op add an authority-only gameplay boundary; client collision may stop local presentation only. `ProcessTouch`, original handlers, HPawn.OnSpellHit, trigger activation, pickups and resultant movers/world events must remain authoritative. Ordinary non-simulated functions alone are not proof of safety if a client locally spawned an authority-role spell. Prevent local gameplay spell spawning.

Existing Versus RPC validates authority, owner, whitelist, life and cooldown (`V18/HPVersusHarry.uc:2510–2693`, `HPVersusWand.uc:330–386`), but charge is just client value clamped 0..1 and muzzle validation accepts any candidate within a pawn radius. No wall trace occurs in the ordinary cast acceptance block. The hide/seek Trace at 2556 is unrelated. Co-op targeting needs original interaction reach/line-of-sight/front-facing validation plus a server-derived muzzle or obstruction-checked candidate.

`G/baseWand.uc:473–475` provides short-range auto-hit for HPawn targets. Any replacement server spawn path must preserve intended close-range interaction without additionally dispatching hit after natural collision. Use one authoritative resolution path and log one result per cast.

## Minimal implementation sequence

1. Create `HPCoopHarry` from original Harry with opt-in common movement hooks and local camera/anim/status bootstrap. Keep original spellbook, aiming animation and campaign state logic. Keep Level.PlayerHarryActor as StoryLeader only on authority; local compatibility alias may point at owning viewport only on clients. A listen server needs explicit care: local alias writes must not overwrite authority StoryLeader.
2. Create `HPCoopWand extends baseWand` with explicit Owner/Instigator, guarded local FX, owner-scoped Lumos, and a server-only spawn entry that instantiates original class. Do not use HPVersusSpell or accept an arbitrary client Class argument.
3. Override the virtual ordinary `Cast()` to submit a reliable owning-pawn request with target actor, target offset, aim and cast serial. Server selects class from target vulnerability and server-owned spellbook, rejects dead/captured/invalid/cooldown/out-of-reach/occluded requests, bounds offset to target geometry and validates muzzle obstruction. Forced boss/duel/sword behavior remains a distinct checked branch, not accidental fallthrough.
4. Server sets `Owner=Instigator=caster` and original target/offset, then calls original `InitSpell` and wand bookkeeping exactly once. Preserve `OnSpellInit` seeking behavior; do not overwrite randomized original direction afterward with a generic Versus aim assignment. `spellRictusempra.OnSpellInit:12` expects a valid target.
5. Provide original-projectile client presentation without running original world hit handlers locally. Add narrow multiplayer opt-in hooks to baseSpell only where subclasses cannot solve initialization/cleanup safely. Rebind reflection attribution, and guard absent dedicated-only FX calls (`SetSpellDirection:316`, `SetSpellCharge:347`).
6. Fix the immediate ordinary-map target exception, gargoyle, to use the actual caster. Fix LumosLight bootstrap before spawning a partner's light. Repair StatusGroup and HudItemManager context paths; merely assigning StatusManager.PlayerHarry is insufficient.
7. Prove one original trigger and one HPawn interaction from each player, one authoritative world event, both local cursors and both projectile presentations. Only then expand object/enemy special cases.

## Required checks

- Clean UCC make after each logical patch. This audit did not invoke UCC or claim compile success.
- Standalone: original initial spellbook/auto-selection, Flipendo/Lumos/Alohomora, charge, spell lesson, close-range object, gargoyle, HUD, camera/cutscene restore unchanged.
- Dedicated + two clients: independent cursor owner/camera/wand; player 1 cast must never overwrite player 0 wand, target, charge, Lumos or health display. Test travel/reconnect after legacy Entry pawn bootstrap.
- Server traces: `[MP_SPELL]` includes cast serial, caster, owner, instigator, selected original class, target, target offset, accepted/rejected reason and one hit/event. No every-Tick log spam.
- Two-player simultaneous cast: each valid cast creates one projectile; one-shot spellTrigger activates once; both clients see its resulting world state. Repeated trigger policy must retain original ReTriggerDelay semantics.
- Aim near walls, behind an obstruction, at inactive/front-only trigger, unknown spell and destroyed target; malformed target/offset cannot select another actor or bypass progression.
- Dedicated has no `Accessed None` from WeaponLoc/Cam/Player.Console/StatusGroup HUD. A successful compile does not establish this runtime property.
- Actual remote enemy projectile collision damages the player touched, not StoryLeader; late target/owner replication does not bind projectile FX to the wrong player.
- Two physical-PC execution, full campaign completion, original-spell FX compatibility and cutscene/travel restoration remain unconfirmed until test evidence exists.
