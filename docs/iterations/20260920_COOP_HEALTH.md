# Co-op health and single-player recovery

Commit: commit containing this report; build-time HEAD `7524213`, sourceDirty=true.
Branch: `coop`.

Changed files: HPCoopGame/Harry, HPCoopHarryAnimChannel, HPCoopStart,
HPCoopHealthProbe, explicit launcher RuntimeProbe option, health/native tick audits.
HPCoopLumosProbe is a separate opt-in fixture; its partial result is below.

Why: original health is owned by each Harry's StatusManager, whereas restored
single-player death enters a native LoadGame loop. Neither client-side health
changes nor that reload path is a valid multiplayer contract. Native M212 also
skips script Tick/PlayerTick, ProcessState and ordinary physics for an authority
pawn whose RemoteRole is AutonomousProxy. A latent death wait on that pawn never
completes; inherited special movement and scripted walk need separate work.

The co-op subclass now applies original damage once on authority, publishes owner
status revisions and completes potion use through the original animation channel
on the server. Death cancels treatment, locks movement and changes presentation.
The existing Game tick observes native animation completion, then tries a checked
position near a living teammate. Recovery restores 41 health and requires an owner
acknowledgement before accepting movement. The owner's prediction history is
cleared at the lifecycle boundary. There is no invulnerability or full-health reset.

All-dead recovery remains explicitly BLOCKED pending a shared checkpoint contract.
This implementation does not make SavePoint/frontend save/load safe by itself.

Build: **PASS**, `20260920-172646-691`, UCC 0 errors / 268 warnings.

- HGame SHA256: `e10e3fa2499549a28105a8986f7dedff584f9e5dff5dc82ce3109e158f294af7`.
- M212Share SHA256: `8075d9ef84521637171bdd52f90c6171dbb8c829ef6c6ede33fd974853042255`.
- Source manifest and UCC log: `.local/builds/20260920-172646-691/`.

Automated/local tests: dedicated server plus two real loopback clients, all using
the same packages and the explicit Ch1 lesson-complete test stage:

- Server: `coop-host-20260920-172741-742-9ed7a1`.
- Client slot 0: `coop-join-20260920-172742-028-2f4134`.
- Client slot 1: `coop-join-20260920-172750-478-0e55c4`.
- Health fixture phases 0–12: **PASS**. Raw 10 damage gives 12/20/30 on the three
  original difficulties; the other player's health remains unchanged. Acid
  throttling advances and rejects an immediate repeated hit.
- Manual, duplicate-request, automatic and interrupted potion cases: **PASS**.
  Original animation completion consumes one potion and heals once. Pit death
  cancels a pending drink without consuming its potion. Inventory is explicitly
  seeded by this fixture; pickup acquisition is not tested.
- Slot 0 instant death → checked revive at `(4760.823242,-28.451380,-723.5)` with
  41 health → owner serial 2 acknowledgement: **PASS**.
- Slot 1 normal death → native `faint` completion at frame `0.993378` → revive at
  `(4682.823242,-28.451387,-723.5)` with 41 health → acknowledgement: **PASS**.
- Both dead → stable, reported checkpoint BLOCKED state with live connections:
  **PASS for refusal of unsupported reload**, not checkpoint recovery.
- Collected client logs contain exactly the expected 14 and 7 owner status
  revisions, respectively. Health/potential/potion counts match the corresponding
  server slot; every logged applied HUD count matches the authoritative count.
  Actor names differ across processes, so correspondence uses the login slot.
  No client `Accessed None`, `Critical` or refused death-position placement.
- Dynamic HPCoopStart succeeds and starts slot 1 96 units from slot 0. Original
  PlayerStart cannot be spawned because it is static; returning that same start
  had previously stacked the players. Wider spawn/floor/reconnect cases are open.

Earlier failures retained in local run logs:

1. Build 165248: acid timer did not advance in skipped Harry.Tick.
2. Builds 165705/170548: latent CoopDead completion never ran; no revive search.
3. Build 170921: all candidate positions overlapped the already finished intro
   CutScene. Build 171722 reached candidate search but rejected NewMusicTrigger1.
4. The final predicate permits only a finished, nonblocking, exact one-shot
   CutScene, or exact nonblocking MusicTrigger/NewMusicTrigger with empty Event
   and no music-loop event. Active story triggers and unknown subclasses remain
   rejected. Music may refresh; no gameplay event is bypassed.

2-PC tests required: actual enemy damage and HUD on each owner; potion input,
upper-body/remote animations, faint/club/pit presentation, movement after recovery,
collision on slopes and near hazards, repeated deaths, latency/loss and old
movement packets. Physical acceptance remains NOT RUN; the user will run it.

Confirmed working: the compilation and narrow runtime assertions above.
Unconfirmed: natural fall damage, club/slow death, moving-platform recovery,
rendered animation parity, physical controls and campaign checkpoint/save/travel.
SP and Versus runtime regressions have not been run for this change; all new
health logic is in co-op classes and no base-source recipe changed in this block.

Known limitations: original server warnings in map Harry.PreBeginPlay and snail
EndTrail remain. Intro capture/release logs do not prove Harry's scripted walk:
`walkto ... *` is asynchronous, and its original latent state is skipped on the
remote authority pawn. Shared camera presentation still needs visual inspection.

Next step: finish the original Lumos hit test, guard unsupported checkpoint/menu
side effects, then authoritative personal pickups and the native special-state
contract. Milestone 1 and the campaign remain unfinished.

## Lumos fixture on the same binary

Server `coop-host-20260920-172957-649-b9d302`, clients
`coop-join-20260920-172957-921-64941a` and
`coop-join-20260920-173006-351-474097`: **FAIL phase 2**, second hit timeout.
Slot 0's normal ServerCastCoopSpell spawned original spellLumos0, hit actual map
gargoyle0 and activated that owner's LumosLight. Slot 1 spawned original spellLumos1
toward actual gargoyle3, but its hit/light activation was not observed within five
seconds. Cleanup switched off only the first observed activation. Two active
lights and original expiry are not yet proven. The next iteration must distinguish
trajectory/fixture placement from gameplay failure; no fake hit is supplied.

The diagnostic temporarily places each server pawn at a checked casting position
and restores it synchronously, using ordinary validation and real projectile
collision. This tests neither natural navigation, player input, client rendering
nor the complete map puzzle.
