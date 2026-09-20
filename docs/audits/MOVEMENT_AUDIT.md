# HP2/M212 movement and state compatibility audit

Date: 2026-09-20. Scope: read-only inspection of the supplied installed UnrealScript and v18; no game execution, build, or two-PC test was performed by this audit worker. All current compatibility conclusions below are **static findings or explicit hypotheses**, not new runtime PASS results.

## Sources and provenance

`GAME` means the absolute local directory `C:/Users/user/Documents/ChatGPT/Доработка Harry_Potter_2/Гарри Поттер и Тайная комната`. Source citations below give the path below `GAME` and one-based line numbers in the supplied snapshot. `H` = `HGame/Classes/harry.uc`; `V` = `HGame/Classes/HPVersusHarry.uc`; `PP` = `Engine/Classes/PlayerPawn.uc`; `P` = `Engine/Classes/Pawn.uc`; `A` = `Engine/Classes/Actor.uc`; `HC` = `HGame/Classes/cHarryAnimChannel.uc`. These are location aliases, not upstream version guarantees.

Read first: handoff `00_START_HERE/START_HERE_RU.md`, `CURRENT_STATE_AND_RISKS_RU.md`, `04_REPORTS/Architecture_Audit_RU.md`, and `Iteration_16_Report_RU.md`.

Installed `H` matches `v18/v18/HGame/Classes/harry.uc`, SHA256 `C4DFE134FDC5DA24D691296CC65F60999CB5B8FA60E1E6DACEFA485FEF09F6C3`. Installed `V` matches its v18 counterpart, SHA256 `C8AFC1A0183F1C49F5C6620C764A6621AE50CC26DEB551A6DAF85E35B1AB7E74`. This proves matching source snapshots only; it does not prove the installed HGame.u was built from them.

The engine scripts explicitly expose M212/HP2 extensions (`Mount`, `MaxMountHeight`, animation-driven movement, root-bone animation, spline movement). No engine physics C++ implementation was located in the audited tree; shader headers are not that implementation. Do not assume modern UE CharacterMovement, movement modes, RootMotionSource, or 469-specific ServerMove_v2 APIs exist here.

## Highest-priority findings

1. **Do not derive campaign co-op directly from HPVersusHarry.** `V:1683` ApplyVersusInput clears `bKeepStationary`, `bIsCaptured`, `bFrozen`, and forces every state to PlayerWalking at `V:1693–1704`. It runs after Super.PlayerInput every local input frame (`V:1848–1863`). This explicitly interrupts the genuine mount, scripted movement, potion, frozen, and cutscene states. Server direct movement similarly forces PlayerWalking (`V:1650–1671`). This is a source-proven conflict, independent of network quality.
2. **Walking opt-in is not complete state networking.** `H:4432–4435` replays corrections only in PlayerWalking; `H:4682–4688` opts into ReplicateMove only in PlayerWalking.PlayerMove. MountFinish, scripted movement, and other HP2 states do not acquire a valid prediction/correction contract from these hooks.
3. **Ledges are native auto-mount plus HP2 animation-driven movement.** The real flow is `Pawn.Mount(Delta)` -> `harry.Mount` -> `Mounting` -> `MountFinish` -> PlayerWalking. No separately declared `LedgeGrab`/`LedgeHang` state exists in Harry. Climb sequences must be audited as part of this flow, not implemented as an unrelated teleport/RPC action.
4. **Mount correction lacks essential context.** The installed correction RPC carries state, physics, position, velocity and Base (`PP:892–942`), but not Destination, MountDelta, MountBase, bFallingMount, climb sequence phase or root-motion progress. `SavedMove` contains input/timestamp data, not these special-state values (`Engine/Classes/SavedMove.uc:8–19`). Simply re-entering MountFinish after a correction cannot be assumed to reconstruct the same movement.
5. **Camera selection is also a movement-state regression.** `H:4789–4792` PlayerWalking.BeginState takes the first BaseCam found. A correct owner-specific camera at login can be replaced when a mount/correction returns to walking. Global PlayerTick also dereferences BaseCam(ViewTarget) before checking ViewTarget (`H:3820–3824`). Dedicated server and all state transitions need explicit context handling.
6. **v18 native mode is not established as its default.** `V:40` declares bUseEngineNetworkMovement; its defaultproperties do not set it true. Assignments are the diagnostic toggles at `V:1515,1537`. Therefore static class default is false. Historical reports that native mode worked do not prove a present launch enabled it.

## Installed UE1 network pipeline

| Stage | Source evidence | Implication |
|---|---|---|
| Client input and prediction | PP:1026 ReplicateMove; PP:1045 saved/pending moves; PP:1121–1122 ProcessMove then AutonomousPhysics | Do not also run a manual physics step or MoveSmooth bridge when native prediction is enabled. |
| Unreliable movement request | PP:333 replication declaration; PP:1183 ServerMove call | Native timestamped input already exists. |
| Server stale rejection | PP:689–691 | Old timestamps are discarded. |
| Server movement | PP:775–820; PP:862–887 MoveAutonomous | State-dispatched ProcessMove followed by AutonomousPhysics; server authority must still apply all state-specific restrictions. |
| Correction | PP:831–852; PP:892–943 | Carries state, physics, location, velocity, Base; Mover bases use relative coordinates. |
| Replay | PP:945–995 | Drops acknowledged moves, sets bUpdating, replays remaining inputs through MoveAutonomous. Harry-specific one-shot effects must not repeat on replay. |
| Base / proxy transforms | A:2844–2863 | Location, rotation, base, velocity and physics have different conditions. A remote PHYS_None is not by itself evidence of broken gravity. |
| Body animation | A:2866–2867 | Simulated proxies receive AnimSequence/SimAnim. Autonomous owners must select/play their own body animation. |
| Owner movement parameters | P:467–470 | GroundSpeed, AirControl, JumpZ etc. are owner replicated. Harry-specific effect state and GroundJumpSpeed are not listed here. |

`Actor` and `Pawn` declare native replication. Their script replication declarations are useful interface evidence; exact native special cases remain a runtime/source boundary.

## Actual ledge/mount flow

`P:146–159` declares MaxStepHeight, MaxMountHeight and mount context. `P:559` documents Mount as the physics-detected event. `H:6399` sets MaxMountHeight=96.5; this is an auto-mount limit, not a guarantee that all geometry up to that height succeeds.

| Step | Implementation | Compatibility issue |
|---|---|---|
| Native contact decides to mount | P:559; H:3488–3493 | Harry drops a carried actor, records Destination=Location+Delta and MountBase=Base, then changes state. Owner and server detection must agree; dropping an actor is a world effect and must not execute twice during prediction/replay. |
| Enter Mounting | H:3500–3508 | Records whether falling, zeros motion, changes to PHYS_Projectile, sets mount base. |
| Choose root-bone sequence | H:3516–3546 | Subtracts horizontal clearance, chooses falling high climb96end, low climb32 (<48*DrawScale), medium climb64 (<80*DrawScale), or climb96start, and adjusts residual MountDelta.Z. |
| Animation moves the pawn | A:35; A:2962; H:3526,3532,3538,3544 | bAnimMove is explicitly documented as animation-driven actor movement, including Harry climbing. RootBone 'Move' has native motion semantics; do not replace it with a cosmetic loop. |
| Enter MountFinish | H:3565–3570 | Halves collision radius/height and offsets PrePivot. Dimensions must stay balanced across rejected prediction, interruption, correction and death. |
| Residual offset | H:3553–3563 | PlayerTick zeros acceleration/velocity and uses Move(MountDelta * DeltaTime * AnimRate), Z only. It does not call ReplicateMove or ClientUpdatePosition. |
| Long climb second phase | H:3585–3591 | If climb96start, halves MountDelta, waits for animation, then plays climb96end. Latent animation phase is not in native SavedMove. |
| Return to walk | H:3592–3596; H:3578–3582 | FinishAnim, PHYS_Walking, idle, then PlayerWalking; EndState restores PrePivot/collision. Walking BeginState can select another player's camera. |

Inherited `P:2965–2969` MountFinish.Tick forwards PlayerTick for other pawns. The exact interaction between inherited state functions, player network tick dispatch, root animation advancement and dedicated-server remote players needs measurement on this engine; it cannot be resolved by assuming a standard UE1 tick schedule. Neither adding another unconditional Tick step nor disabling native root motion everywhere is justified by this audit.

There is no declared sustained ledge-hang mode in the inspected Harry state inventory. Acceptance should still test the visible catch/hang phase of falling-high climbs, failed catches, interruption, and recovery after correction. A gameplay request to hang indefinitely would be a new feature.

## Movement compatibility matrix

`HISTORICAL` below means the handoff reports prior tests; it is not a fresh verification and does not establish current source/binary provenance. `UNVERIFIED` means no current runtime result. `BLOCKED` means source contains a concrete incompatibility requiring repair/test. All rows require dedicated server + owner + observer parity before acceptance.

| Behaviour | Real path and evidence | Static result | Runtime evidence |
|---|---|---|---|
| Idle / fidget | H:3262–3317; PlayerWalking.AnimEnd H:4187 | Owner needs cHarryAnimChannel; random fidgets need not choose identical random values independently. | HISTORICAL idle/land recovery; current UNVERIFIED |
| Walk | H:4212–4222; PP:4041 inherited walking behavior; H:6341 Walk entry | V desired-animation classifier returns run for forward movement (V:1378–1399); true walk parity is not established. | UNVERIFIED |
| Run | H:3205–3241; H:4573–4767 | Native walking hooks present, direct fallback retained. | HISTORICAL horizontal movement |
| Backward | H:3219–3224 | Direction selected from acceleration against actor forward. | HISTORICAL runback |
| Strafe | H:3226–3230 | Actor-relative acceleration classification. | HISTORICAL left/right strafe |
| Diagonal | H:4660; H:3219 | Combined axes and classification threshold 0.75; physics clamp/diagonal speed requires measurement. | UNVERIFIED |
| Turning / camera-relative move | H:4646–4660; H:4680–4696; H:4711 | Harry sets OldRotation immediately before movement call; server derives rotation from view RPC. Verify desired yaw and actor yaw during correction. | UNVERIFIED |
| Stationary jump | H:2437–2495 | bPressedJump reaches DoJump via H:4720; native payload carries jump edge. | HISTORICAL jump |
| Running jump | H:2473–2494 | Chooses Jump2; caps horizontal speed to GroundJumpSpeed; includes Base.Velocity. | UNVERIFIED as separate case |
| Falling / walk off edge | H:2306–2316; H:4526–4565 | ProcessFalling bookkeeping is in PlayerTick, outside replay ProcessMove; server/owner fall time/height parity is not proven. | HISTORICAL proxy jump arc; current UNVERIFIED |
| Landing | H:4266–4364 | Animation, sounds, fall damage, spongify detection and large-body effects share callback. Replay/world-effect duplication and server fall-height bookkeeping require audit. | HISTORICAL Land -> idle_1 in v15 logs |
| Slopes | Native PHYS_Walking; P:210 Floor | No separate Harry state; engine implementation not available here. | UNVERIFIED |
| Steps / stair response | P:146,162,564; H:6399 | Native steps and mount threshold must be separated in tests. | UNVERIFIED |
| Wall/pawn collision | H:4131–4165; PP:1106–1116 | Director callbacks can occur during predicted/replayed contact. Server must own world effects. | UNVERIFIED |
| Moving platforms | H:2490–2493; PP:834–835,920–922 | Standard Mover-relative correction exists; mount base and non-Mover scripted platforms need separate tests. | UNVERIFIED |
| Push / knockback | H:2277–2286; HC:207–244; H:4882 | Overlay response and additional acceleration exist; vAdditionalAccel consumed only in ProcessAccel lock-on path. Effect context must match owner/server. | UNVERIFIED |
| Ledge grab / visible hang | P:559 -> H:3488; H:3523–3527 | BLOCKED by V forced walking and incomplete special-state correction. | UNVERIFIED |
| Pull-up / mantle / tall edge traversal | H:3496–3597 | BLOCKED: root-motion and residual-offset phase are not captured/replayed; camera/capsule transitions need reconciliation. | UNVERIFIED |
| Ecto movement/jump | H:2453–2458,6343; HC:254 | Jump is a channel reaction and returns without normal ballistic jump. Cannot force a generic jump. | UNVERIFIED |
| Sleepy movement/jump | H:2459–2464,6345; HC:355 | Similar special overlay gate. | UNVERIFIED |
| Web movement/jump | H:6349; HC:392 | Movement-animation channel rejects locomotion replacement while active. | UNVERIFIED |
| Sword movement/aim charge | H:4667–4670,6347 | Charging changes GroundSpeed and uses dedicated sequences; keep original baseWand context. | UNVERIFIED |
| Dueling movement | H:2445,4661–4664,6351 | Jump deliberately disabled; run/strafe variants and large acceleration input differ. | UNVERIFIED |
| Spongify bounce | H:4292–4310,4503–4512 | Bounce/target range/camera/FX occur in PlayerTick; move replay alone does not serialize pad event. | UNVERIFIED |
| Boss lock / rail constraints | H:2091–2177; H:4837–4910 | BossTarget, fixed direction and plane constraints influence input. Cannot clear these locks every frame. | UNVERIFIED |
| Carry / throw while moving | H:1378–1398,4487–4499; HC:65–99 | Attach/drop/throw are world operations, not purely cosmetic channel state. | UNVERIFIED |
| Duck/crawl | H:3250–3259 | Functions and SneakF sequence exist; exposure through actual campaign input is not established. | UNVERIFIED / reachability required |

## Complete declared state inventory for the audited core

Enumerated with case-insensitive state matching including editor-visible `state()` declarations. A state name is not itself a movement mode; this inventory includes blocking/presentation states because blanket walking recovery destroys them too.

### harry.uc: all 20 declared states

| State | Line | Movement/control significance | Network assessment |
|---|---:|---|---|
| statePickupItem | 1378 | Stops horizontal motion, turns, pickup animation/channel, returns to walking | World attach must be authoritative; UNVERIFIED |
| statePotionMixingBegin | 1453 | Stops horizontal movement | Preserve lock; UNVERIFIED |
| statePotionMixingStir | 1466 | Turns to cauldron, loops animation/sound | Canonical story interaction + local presentation; UNVERIFIED |
| statePotionMixingIdle | 1499 | Idle animation until story transition | Preserve; UNVERIFIED |
| stateDead | 1616 | Stops movement, faint animation, death logic | Dedicated co-op death/checkpoint policy required |
| stateInactive | 1770 | Ignores jump/fire/damage | Preserve intentional inactivity |
| LookAtActor | 1920 | Idle/look control | Preserve scripted state |
| wingspell | 1933 | PHYS_Rotating and focus-actor turn loop | Legacy levitation context; UNVERIFIED |
| Mounting | 3496 | Selects climb/root-motion phase | BLOCKED as detailed above |
| MountFinish | 3549 | Capsule change + residual movement + FinishAnim | BLOCKED as detailed above |
| statePickBitOfGoyle | 3599 | Zero motion, ingredient animation, returns walking | Story completion once; UNVERIFIED |
| ChessDeath | 3612 | Calls KillHarry | Co-op death policy required |
| CelebrateCardSet | 3625 | Camera sequence / reward side effects | Story/local presentation split; UNVERIFIED |
| PlayerWalking | 4126 | Ground and ballistic gameplay; optional native hooks | Partial historical coverage only |
| GameEnded | 4913 | Ignores damage/physical notifications, inherits end behavior | Match/story policy required |
| waitForDeath | 5030 | MoveToward bustedBy / scripted capture | Server scripted locomotion; UNVERIFIED |
| exittoMenu | 5112 | RestartGame then freeze | Shared session policy required |
| harryfrozen | 5119 | Ignores PlayerTick and interactions | Do not override with input recovery |
| SpellLearning | 5180 | Ignores ProcessMove; routes input to lesson | Dedicated special-mechanic protocol required |
| stateCutIdle | 5264 | Zero motion + idle | Server controls story lock; client presentation |

### Inherited Engine states reachable by Harry

`PP` declares: InvalidState (3896), PlayerWalking (3916, overridden by Harry), FeigningDeath (4270), PlayerSwimming (4461), PlayerFlying (4689), CheatFlying (4742), PlayerWaiting (4804), PlayerSpectating (4898), PlayerWaking (4988), Dying (5044), GameEnded (5329, Harry override). Their PlayerTick/PlayerMove implementations generally include native replay and ReplicateMove (e.g. PP:4620–4664 swimming, 4700–4731 flying). **None is newly runtime verified.** Swimming is explicitly reachable from Harry.PlayerWalking.ZoneChange (`H:4178–4184`); spectators/cheats are engine capabilities, not proof that campaign content uses them. Harry health death uses stateDead and cannot be assumed identical to Engine.Dying.

`P` adds Dying (2605), GameEnded (2652), stateInactive (2780), stateMovingToLoc (2788), Mounting (2868), MountFinish (2943), stateTurningTo (3128), patrolFollowSpline (3444), stateSplinePause (3533), DoingTalk (4013), DoingCutAnimate (4482), PathToGoal (4672). More derived overrides take precedence. Script walk/run, turn, spline, talk and animation states are **UNVERIFIED server story flows**, not free-input prediction states. Spline setup sets PHYS_Interpolating and disables collision (`P:3311–3313`). PathToGoal can set StateToGotoAfterMount (`P:4732,4760,4779`); Harry's own MountFinish instead always returns PlayerWalking (`H:3596`), so scripted path/mount interactions need explicit testing.

### HPawn and animation-channel states

Harry extends PlayerPawn (`H:5`), while HPawn extends Pawn (`HGame/Classes/HPawn.uc:5`): **HPawn is not Harry's superclass**. HPawn states are world/AI actor movement and must execute on authority, with proxies presenting the result.

HPawn declares stateIdle (215), stateInfoPrint (219), stateBeingThrown (227), patrol (414), statePatrolPointPause (622), stateLeadingActor (922), stateLeadingActorPause (940), stateDestroy (1212). Patrol can issue MoveSmooth for requested world motion (`HPawn:475–483`), while thrown actors have Landed/Touch/Bump/HitWall callbacks (`227–247`). These do not justify bypassing PlayerPawn prediction for players. All are UNVERIFIED for co-op authoritative world ownership.

HC declares stateIdle (56), statePickupItem (65), stateThrow (85), stateCasting (101), stateCancelCasting (120), stateDuelingCast (130), stateDefenceCast (147), stateCast (175), stateKnockBack (215), stateEctoJump (254), stateDrinkWiggenwell (293), stateSleepyJump (355), stateWebJump (392), stateReactRictusempra (431), stateReactMimbleWimble (457). Movement gates in Ecto/Sleepy/Web return false from PlayHarryMovementAnims; preserve them. Cast.EndState can cast if interrupted (`HC:189–199`); potion EndState consumes inventory and heals (`HC:302–310`). Replaying/interruption must not duplicate these effects. A full cHarryAnimChannel must never be created indiscriminately on remote proxies.

`HGame/Classes/cAnimChannel.uc` declares stateIdle (17), stateCast (33), stateCharging (70), stateDefence (86), stateKnockBack (113), stateReactRictusempra (141), stateReactMimbleWimble (175). These related character animation states require their own actor authority context; they do not replace Harry's channel. `HPVersusRemoteAnimChannel.uc` has stateIdle (21), stateRelease (27), stateCast (31), deliberately visual-only; its limited cast presentation is not complete replication of HC.

### Specialized Harry subclasses found

`HGame/Classes/Quidditch/BroomHarry.uc`: PlayerWalking (1035, PHYS_Flying), PlayerMove (1110), stateCutIdle (1584), FlyingOnPath (1616), Pursue (1662), Hit (1713), BroomDying (1736), Catching (1780). `HGame/Classes/Misc/FlyingCarHarry.uc:158–166` overrides PlayerWalking and enters PHYS_Flying. These are separate special-mechanic movement implementations; ordinary HPCoopHarry does not automatically network them. Goyle-related classes also exist, and Harry carries bIsGoyle plus altered animations; apparent mesh selection alone is not a compatibility implementation. All special mechanics remain UNVERIFIED.

## Minimal implementation architecture

1. Create `HPCoopHarry extends harry`; keep `HPCoopGame`, PRI/GRI and player registry separate from Versus. Native movement opt-in should return true only where the co-op movement contract is implemented. Preserve v7 direct movement as a reference/fallback in its existing mode, never run it simultaneously with native prediction.
2. Extract/reuse narrow owner-aware camera, cursor/wand and animation-channel bootstrap from the existing work. Check `Viewport(Player)` for local presentation and authority separately for gameplay. Fix PlayerWalking camera reacquisition with a virtual owner resolver; do not use the first BaseCam globally. Ensure every callback is safe on a dedicated server with no local Player.Console.
3. Preserve all original gameplay states and locks. Recovery after travel should be an explicit lifecycle transition, not a per-frame GotoState(PlayerWalking). Keep health/world authority independent from local UI.
4. Add special-movement transition instrumentation before changing mount math: state before/after; accepted move timestamp; Role/RemoteRole; Physics; Location/Velocity/Acceleration; Rotation/DesiredRotation; Base/Floor; Destination/MountDelta/MountBase/bFallingMount; capsule dimensions; PrePivot/SavedPrePivotZ; AnimSequence/AnimFrame/AnimRate; bAnimMove; bUpdating. Log transitions and corrections behind a debug flag, not every tick.
5. Define one reusable HP2 special-state synchronization contract for mount, scripted movement and other animation-driven actions. Authority validates/initiates transition; owner receives transition identity, relevant context and phase; observer receives presentation. Decide where prediction is possible and where a short authoritative transition is required. Reconcile correction/replay against that transition identity, suppress repeated side effects and restore capsule exactly once. **This is a design requirement, not an implemented or proven solution.** Do not serialize raw client Destination as authoritative or add a blind location RPC.
6. Test root-animation advancement and MountFinish residual displacement under this engine before relocating it into ProcessMove. Merely calling ReplicateMove from MountFinish would not make the native animation clock rewind with SavedMove. An Engine/native extension may be necessary if the available script interface cannot restore phase deterministically; evidence is required before choosing it.
7. Separate ProcessFalling bookkeeping and authoritative landing effects from local audio/camera. Consume world interactions once on authority. Keep ordinary walking prediction and replay inherited from PP.

## Acceptance protocol prepared by this audit

No steps below were executed here. Use a story map with real ledges and then a controlled height/platform fixture. Record one server log and both client logs/video against the same build hash.

- Verify two distinct pawns/slots, owning Role=AutonomousProxy, observer SimulatedProxy, and owner-specific Cam/ViewTarget/channel before motion.
- Run idle, true walk, forward/back/strafe, all diagonal combinations and direction reversals; jump from rest/running, fall off edges, land still and while holding movement. Compare actor/capsule positions, not mesh feet alone.
- Exercise slopes, stair edges, wall slide, player collision, static/moving bases, platform jump inheritance and server knockback.
- Mount low/medium/high geometry, high edge while falling, near threshold heights and oblique approach; hold input throughout; interrupt by damage/death/story lock. Verify full capsule restores and original camera remains attached.
- Inject or reproduce correction during each mount phase and immediately after returning to walking. Verify no double capsule scaling, root-motion replay, teleport, residual drift, stuck state or duplicated carried-object drop.
- Observe all mount phases from the other client; compare actor location, collision dimensions, animation and render offset. Do not force remote PHYS_Walking merely because proxy PHYS_None appears in logs.
- Repeat after join/reconnect and map travel; verify initial state and all owner helpers are restored. Repeat under realistic LAN/WAN latency and loss when available.
- Then test ecto/sleepy/web, sword/duel constraints, Spongify, carry/throw, scripted walk/spline/turn, frozen/cutscene input and specialized subclasses.

PASS requires fresh paired evidence for owner/server/observer and a matching clean build. Current audit outcome: historical basic movement survives as evidence; complete movement, ledge/correction compatibility and campaign special states remain unconfirmed, with concrete blockers identified above.
