# Ch1: authoritative health, death and recovery audit

Status as of 2026-09-20: **implementation applied; the dedicated authority health
fixture passed phases 0-12 on build 20260920-172646-691**. This is server-state
and lifecycle acknowledgement evidence, not UI, player-input or two-PC acceptance.
The current implementation is in `mod/HGame/Classes/HPCoopHarry.uc`,
`HPCoopGame.uc`, and `HPCoopHarryAnimChannel.uc`. `HPCoopHealthProbe.uc` is an
explicit disposable test fixture. The earlier `.local/proposals/coop-health.patch`
and manifest are historical review artifacts, not patches to reapply to the
current core. This audit/review did not launch the game or UCC.

## Source contract

Paths below are relative to the supplied `Гарри Поттер и Тайная комната/` source
tree unless marked otherwise. The original Harry function bodies are those restored
by `patches/restore-legacy-gameplay.json`; `.local/upstream-harry.uc` is the private
upstream comparison copy, not a distributable replacement source file.

| Path / function | Evidence and consequence |
|---|---|
| `HGame/Classes/StatusItems/StatusItemHealth.uc:348–352` | Initial count 100, current capacity 100, absolute capacity limit 600. Capacity must travel to the owner's HUD separately from current count. |
| `StatusItems/StatusItem.uc:54–105` | `IncrementCount` delegates to clamped `SetCount`; `nCurrCountPotential` takes precedence over `nMaxCount`. `StatusItemHealth.IncrementCountPotential:53` also fills newly increased capacity. Keep these original operations on authority. |
| `harry.uc:1775–1822`, `HarryIsDead:5101` | Health methods use the owner's `managerStatus`; death is count <= 0. `Pawn.Health` alone is not Harry's health model. |
| Original `.local/upstream-harry.uc:2278`, recipe function `TakeDamage` | Original difficulty multiplies raw damage by Easy 1.2 / Medium 2 / Hard 3, then minimum scalar 1 and integer assignment. It preserves carried-attacker immunity, hurt sounds, visual flashes, knockback, acid throttling, instant/club/slow death and auto-quaff. Call this restored body once on authority. Do not replace it with Pawn.TakeDamage. |
| `harry.uc:6323–6329,6387` | Defaults for those multipliers/minimum and `iMinHealthAfterDeath=41`; no 5000-health pool or regeneration timer is justified. |
| `harry.uc:3803`, original upstream:3959 | `fTimeSinceLastAcidHit` increases in PlayerTick. The current co-op dedicated PlayerTick skips that camera-dependent body: without an authority-only counter, AcidHit remains at zero damage. |
| `harry.uc:4166` PlayerWalking.TakeDamage | State-specific handler calls Director before Global.TakeDamage. A global guard alone prevents health mutation but leaves the client Director callback; the implementation gates this state dispatch too. |
| `harry.uc:5693`, `cHarryAnimChannel.uc:293–340` | Original potion uses the upper-body DrinkPotion animation and EndState consumes one potion, adds 100 health, plays boost audio. EndState also runs on interruption. It is not an authoritative request/commit protocol. |
| `cHarryAnimChannel.uc:207` | DoKnockBack selects the original state; this is a useful presentation hook without duplicating the original damage arithmetic. |
| Original `.local/upstream-harry.uc:1565–1603` | KillHarry enters stateDead; club death also changes facing by a quarter-turn. Ch1 Director.OnPlayerDying/OnPlayersDeath (`Director.uc:142–150`) only log messages. Boss encounter overrides require a later separate audit. |
| Original `.local/upstream-harry.uc:1606–1759` | stateDead plays faint, optionally moves for its fall animation, then repeatedly executes `ConsoleCommand("LoadGame 0")`. This whole latent death state must be bypassed in co-op. |

The supplied v18 health/death hacks are **not** this reference contract. The build
must apply the existing original-gameplay restoration recipe first, including its
Timer restoration. Otherwise `Super.TakeDamage` in the co-op override calls the wrong
handler and the old periodic immortality/state reset can undo the result.

## Applied implementation

The implementation uses the existing owner's StatusManager on the server. Its `TakeDamage`
override requires authority and membership in the game's two-pawn registry, then
calls the restored original once. Its own `SetHealth` and `AddHealth` reject client
gameplay writes. Server health is mirrored to Pawn.Health solely for engine code
that reads that field. Login explicitly clears `bFraserMode` in co-op.

An owner-only reliable status RPC carries one revision with current health,
capacity, absolute limit and potion count. It sends on change, at most once per
0.1-second periodic scan, immediately after damage/potion/death/revive, and forcibly
at the readiness handshake. This also observes capacity changes that bypass
Harry.AddHealth and write StatusManager directly. The local HUD applies only its
own snapshot to its own StatusItemHealth and uses the original change effect.
The counts are not accepted as client RPC arguments. `ApplyCoopStatus` also repairs
accidental local display writes using the last accepted snapshot.

HPCoopHarryAnimChannel inherits the original animation labels, sequences, bottle
attachment and sounds. Only its potion EndState changes: cleanup remains local,
but health/count commit calls the owner and runs only on authority while a server
operation is pending. Client key presses request a drink; the server checks live
registry membership, captured/waiting state, capacity, actual inventory and
animation availability. Manual requests require walking; trusted original
auto-quaff inside TakeDamage retains its broader original timing. There is no
client-completion RPC. Original interrupted-animation completion is preserved;
death explicitly cancels pending treatment before closing the channel.

Knockback uses the original channel on authority plus an owner presentation RPC.
Original server hurt sounds/ClientFlash remain in the original damage handler.
Remote upper-body animation replication still needs a two-client visual check;
this audit does not certify that all AnimChannel state is replicated by M212.

`KillHarry` now enters a separate CoopDead state. It clears pending potion use,
stops the wand/Lumos, keeps authoritative health at zero, stops movement and
collision, and sends an owner lifecycle RPC. It retains the faint sequence, club
rate/frame and death emote; instant deaths hide the body. Recovery waits for the
original faint animation to finish plus its delay. Native M212 skips the authority
remote pawn's script Tick and ProcessState. Consequently periodic status/acid
maintenance and death progression are called by HPCoopGame.Tick through the pawn's
CoopAuthorityTick/CoopAuthorityMovementTick. CoopDead observes instant death or
the real non-looping faint animation ending with IsAnimating(), then waits 0.5
seconds plus the original slow-death delay. It does not depend on latent Sleep
or FinishAnim and does not force animation frames. See
`docs/audits/REMOTE_PAWN_TICK_AUDIT.md` for native addresses and the diagnostic
run that proved the missing completion flag. The old automatic faint
MoveTo/FindFaintLocation is deliberately absent until its collision/root-motion
path is validated. A defensive stateDead override prevents a hard-coded legacy
transition from reaching the native reload loop.

Dead and pending-respawn-ack pawns reject ServerMove before MoveAutonomous. The
owner clears SavedMoves/PendingMove, changes state/location, and acknowledges a
server-issued lifecycle serial. Lifecycle messages include the authority movement
timestamp; ClientAdjustPosition rejects dead/captured corrections. Old
acknowledgements cannot unlock a later death. The latest root changes also close
the owner's local upper-body channel before death, reset HarryAnimType, and apply
the server death facing/location with a failed-placement log. Those owner-death
fixes have been checked in source and are included in the passing fixture build;
visual runtime validation remains pending.
No health immunity is granted while waiting for this acknowledgement.

The game retries single-player recovery at most once per second after the death
animation/minimum delay. It searches eight nearby directions around an alive
walking teammate. A candidate requires static BSP floor, upward floor normal,
bounded height difference, line of sight, full-body clearance and no overlapping
colliding actor/trigger. Native CanFit is an additional check, not a replacement
for explicit actor overlap checks while the dead pawn's collision is disabled.
The root narrowed harmless-overlap exceptions to an exact finished one-shot
CutScene, or exact MusicTrigger/NewMusicTrigger with no blocking flags, empty
Event and no music-loop event callback. Other triggers remain excluded. These
exceptions were exercised by the passing first-room authority fixture; they
are not a general trigger whitelist or proof for other geometry. SetLocation
must succeed at the exact tested point; its
resulting zone must not be kill/pain/water. Dynamic bases are rejected. The player
recovers `min(iMinHealthAfterDeath, own capacity)` health (normally 41), not full
capacity, while retaining personal inventory/progress. Absence of a safe candidate
leaves the pawn dead; the code never falls back to an unchecked PlayerStart.

The candidate checks are conservative, not a proof of safe respawning
on every HP2 collision type. BSP floor alignment, overlap Trace behavior and native
SetLocation callbacks are explicit runtime gates. Enemy projectiles can still hit
a revived player normally; there is no invulnerability window.

## Native save/load evidence and blocker

`Engine/Classes/PlayerPawn.uc:402–411` SaveGame only sets bQueuedToSaveGame. Native
code consumes that flag later. `harry.PreSaveGame:876` changes PreviousLevelName,
forces SloMo and copies the status arrays; `PreClientTravel:922` also copies state,
clears non-travel status and applies the minimum health after death.
`TravelPostAccept:951` restores inventory/status, removes already-owned cards,
sets up duels, selects SmartStart and can queue another save. These callbacks are
not a two-player checkpoint transaction.

The audited development Engine.dll has SHA256
`e7bd8f53aa1bce2386ba8943fdfc4d4c54c0a27948f49bc0de53dee22cc82391`.
Its export `?SaveGame@UGameEngine@@UEAAXH@Z` starts at VA `0x18009F4F0`.
Read-only disassembly is retained privately at
`.local/proposals/engine-save-probe.txt`.

- At `0x18009F605–0x18009F613` it unconditionally follows
  `Engine+0xD8 -> object+0x80 -> first pointer`. It then dereferences that result
  at +0x88 at `0x18009F685` and `0x18009FA18` for script callbacks.
  The first-local-viewport/console interpretation is an inference from engine
  layout; no type-bearing debug symbols were recovered. The actual unguarded
  pointer chain and absence of an earlier null/NetMode guard are directly observed.
- Calls to `ULevel::GetLevelInfo` (export VA `0x180042830`) bracket writes to the
  level object. At `0x18009F7E6` it invokes the imported Core UObject::SavePackage
  through IAT `0x18019AF08`; the filename format is `%s\Save%i.usa` at
  `0x1801BCE08`. This is world/package persistence, not a per-pawn respawn.
- At `0x18009FA12`, IAT `0x18019AF70` resolves to
  Core::SavePersistentActorCache. The later `%s\Save%i.mus` string confirms more
  save components than the pawn fields alone.

This is enough evidence to avoid routing dedicated co-op recovery into native
SaveGame/LoadGame; it is **not** a complete reverse-engineered serialization
contract. No claim is made that saved NetConnections, both player slots, level
actors, cutscene cues and native screening can be restored safely together.

`Misc/SavePoint.uc:51–82` adds a separate problem: touch accepts any Harry but uses
cached PlayerHarry, marks itself inactive and may destroy itself, temporarily
raises that pawn's health, calls the queued save, then immediately restores the
health. Its temporary health is not evidence of what the later native save writes.
HPCoopHarry rejects SaveGame and leaves bQueuedToSaveGame false, but that
alone does **not** keep the checkpoint book from disappearing. Before testing
books, add a co-op-only SavePoint.Touch/OnSaveGame branch **before** those mutations:
authority + actual registered toucher, and report unavailable checkpoint recovery
without consuming the book. Single-player must continue through the original path.

HPConsole.doLevelSave (`Internal/HPConsole.uc:1160–1189`) additionally changes pause
and SloMo and writes GameSaveInfo metadata after calling the pawn's SaveGame. Thus
the pawn override alone does not disable all frontend save side effects. Co-op
save/load menu actions need an explicit disabled/unavailable route until the
checkpoint contract exists. A separate exact-replacement proposal is prepared at
`.local/proposals/coop-save-load-guards.json`, covering SavePoint plus HPConsole
and FEBook entry points before their side effects. It was independently validated
on an isolated source fixture; that does not establish application or UCC/runtime
success in the active game. Original QuickSave/QuickLoad have standalone guards
(`Engine/Classes/PlayerPawn.uc:1957` onwards), but that does not cover every HP menu.

When both connected players are dead, the game latches
`bCoopRecoveryBlocked` and reports
`all-dead-no-verified-shared-checkpoint`. It keeps net ticking for RPC delivery.
It neither reloads nor calls GameInfo.RestartPlayer: that method (`Engine/Classes/
GameInfo.uc:1145`) resets only Pawn.Health and a PlayerStart location, which would
misrepresent a shared campaign checkpoint. The implementation also rejects that generic
restart for HPCoopHarry. Recovery from the latched condition is intentionally
unfinished; a fresh test session is a test reset, **not** checkpoint recovery.

## Remaining first-level integration limits

- ChocolateFrog/WiggenWell are HProp pickups. `Props/HProp.uc:50–59` accepts only
  cached PlayerHarry; PickupProp (`224–293`) depends on its camera/HUD fly effect
  before awarding status. Both personal authority selection and headless pickup
  completion remain separate work. The health implementation does not claim that player
  1 can already collect these items. Tests may explicitly seed a potion on the
  server, labelled as a fixture, to isolate potion handling.
- Card capacity rewards, potion pickups, map transitions, reconnect inventory,
  boss-specific death and all-player checkpoint rollback are not implemented by
  this patch. The snapshot transports authoritative health/capacity if a valid
  server operation changes them; it does not establish those operations' ownership.
- The independent review is `.local/proposals/COOP_HEALTH_REVIEW.md`, with captured
  source hashes and two owner-death findings. The root task applied both in the
  same review cycle; the resulting build passed the authority fixture. Visual
  validation of those specific owner-death cases remains pending.

## Validation performed and required gates

Audit checks: original/v18/restoration comparison, native export/disassembly and
import inspection, isolated original draft application checks, and read-only
review of the current four health classes. No UCC build or game launch was run
by this audit.

Root-reported authority fixture evidence through build 171722 covers phases 0-9:
two separate owner health pools, damage 12/20/30 for raw 10 by difficulty,
acid timing below/above 0.333 seconds and duplicate suppression, one potion
commit after two requests, automatic potion at one health, interrupted potion
EndState, and pit death cancelling a pending potion without consumption. These
are server-state fixture assertions, not visual or real input acceptance. The
fixture seeds potion counts; pickup acquisition is not tested.

Recovery was first blocked before candidate evaluation by the missing latent
death completion. Build 171722 then reached candidate evaluation but remained
BLOCKED on MusicTrigger1 overlap. After the restricted passive-music predicate
and owner-death fixes, build `20260920-172646-691` passed phases 0-12. The collected
server `engine-0.log` in
`.local/runs/coop-host-20260920-172741-742-9ed7a1` records:

- Lines 427-429: slot 0 revived at health 41 beside slot 1 and the owner
  acknowledged lifecycle serial 2.
- Lines 432-438: slot 1 entered non-instant death, the native faint finished at
  frame 0.993378, then slot 1 independently revived at health 41 and acknowledged
  lifecycle serial 2.
- Lines 446-450: both-dead explicitly remained blocked with live connections;
  the fixture ended `result=PASS phase=12` without attempting native reload.

Collected owner logs are
`coop-join-20260920-172742-028-2f4134/engine-0.log` and
`coop-join-20260920-172750-478-0e55c4/engine-0.log`, under `.local/runs`.
Both players were real connected clients on this host. This establishes the
sampled authority progression and owner acknowledgements; it does not establish
all candidate geometries, visual faint quality or separate-machine behaviour.

Additional required checks: owner/remote faint and knockback; potion already
attached on the owner when death arrives; club/slow death; actual pit/enemy
collision rather than direct TakeDamage; narrow corridor, stair/ledge, blocking
partner and moving-platform rejection; no native save/load or save-file changes;
stale ServerMove/ack and packet delay/loss. A completed fixture would still not
prove two-PC gameplay, checkpoint recovery or animation quality.
