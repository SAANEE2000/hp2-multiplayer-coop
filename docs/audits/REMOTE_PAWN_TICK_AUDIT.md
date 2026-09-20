# Authority remote-pawn tick and latent-state audit

Audited 2026-09-20, read-only against the local M212 Engine.dll. This report
contains observations and addresses, not copied engine implementation. Core
changes and runtime validation are owned by the root task.

## Confirmed recovery blocker

The first health fixture did not reach a floor or collision test. On the server,
`HPCoopHarry.CoopDead` depended on latent `Sleep(0.5)` before assigning
`bCoopDeathAnimFinished`. The authority instance of a remote autonomous pawn
does not execute `ProcessState` through the ordinary native actor tick. Thus the
flag remained false and `HPCoopGame.Tick` skipped `TryCoopReviveNear` entirely.

The diagnostic run
`.local/runs/coop-host-20260920-170650-868-7dbe87/server-stdout.log:404`
reported `state=CoopDead`, `death-animation-finished=False`,
`partner-physics=1`, and `partner-base=Ch1Rictusempra.LevelInfo0`. The death at
line 402 was instant. No faint animation needed to finish in this case, and no
candidate-refusal record was emitted. The preceding build's run
`coop-host-20260920-165810-386-12c18b` had the same phase-10 blocker without the
expanded diagnostic fields.

This is separate from the already identified absence of ordinary pawn script
`Tick` on this native branch. Dispatch from the authority Game's tick is the
appropriate place for the co-op status and death progression.

## Native evidence

Engine.dll SHA-256:
`e7bd8f53aa1bce2386ba8943fdfc4d4c54c0a27948f49bc0de53dee22cc82391`.
Preferred image base is `0x180000000`; addresses below are RVAs, so ASLR does
not change their meaning. The function and virtual-table names were resolved
from the binary's exports, rather than guessed from instruction shape alone.

| RVA | Observation |
| --- | --- |
| `0xAF4A0` | Exported `AActor::Tick` starts. |
| `0xB015A`–`0xB0175` | Reads the adjacent role bytes at actor offsets `0xC9`/`0xCA`; selects the remote-autonomous (`3`), authority (`4`) branch. The enum values and declaration order are in `Engine/Classes/Actor.uc:132`. |
| `0xB0202`–`0xB0396` | This branch advances the ordinary timer and named multi-timers and dispatches their callbacks. `0xB027C` references exported `ENGINE_Timer`. |
| `0xB039E` | Jumps to `0xB07C5`, bypassing script tick/player tick and `ProcessState`. |
| `0xB045D` / `0xB051F` | The other branch references `ENGINE_PlayerTick` / `ENGINE_Tick`. |
| `0xB054C` | The other branch calls virtual slot `+0x28`. Both AActor and APlayerPawn vtables resolve that slot to exported `AActor::ProcessState`, RVA `0x101B50`. |

The private continuous inspection output is
`.local/proposals/engine-actortick-continuous.txt`. Older split inspection
outputs cut an instruction at their shared boundary; use the continuous file.

## Animation update is distinct from state execution

Native animation update precedes the role branch. Several paths dispatch
`ENGINE_AnimEnd` before RVA `0xB015A`. For example, actor-self event dispatch
occurs at `0xAFF0F` after loading `ENGINE_AnimEnd` at `0xAFEF3`, and at `0xB0081`
after the load at `0xB0065`. Other paths dispatch on an animation-channel actor.
This proves that skipping `ProcessState` does not itself disable native
animation progression or all animation notifications. Each animation's actual
conditions and owner/channel still need to be checked.

`Actor.IsAnimating()` is available to script (`Actor.uc:2965`). Its script
native at RVA `0xFB7B0` calls exported `AActor::IsAnimating` at `0x4BEC0` for the
main animation when no root bone is supplied. That helper checks animation
sequence and active rate/tween state. Native `FinishAnim` at `0xF9D40` uses the
same helper at `0xF9E52`, then records latent action `0x181` when it must wait.
Polling `IsAnimating` from a Game-dispatched authority function therefore
observes animation state without requiring latent-state execution. It is not
a general substitute for every `FinishAnim`: looping clips, root-bone channels,
and interrupted/replaced animation sequences require their own handling.

For death, preserve the original non-looping `PlayAnim('faint', rate, tween)`
presentation and club start frame. The narrow supported authority progression
is:

1. For instant death, start the post-animation wait immediately.
2. Otherwise wait for `AnimSequence == 'faint' && !IsAnimating()`; if another
   clip replaced faint, do not silently declare that faint completed.
3. After the original 0.5-second wait, plus 1.5 seconds for slow death, set the
   authority completion flag exactly once. Keep the existing four-second
   minimum `CoopRespawnAfter` and all placement checks.

Clients may continue their local animation/latent presentation, but their flag
must not grant server recovery. A client completion RPC is unnecessary. Do not
change RemoteRole or call a broad original state loop merely to force this
single completion condition.

## Placement contract remains conservative

The diagnostic living partner was walking on `LevelInfo0`, so the existing
static-BSP base precondition is satisfied. This does not establish that all
eight candidate positions are safe. The original `Ch1RictuIntro.int` moves
Harry to `CutMark0`; neither a map marker nor the initial PlayerStart proves a
valid partner-adjacent recovery position. The new rejection counters should
be evaluated only after death progression reaches `TryCoopReviveNear`.

The native `CanFit` implementation, RVA `0xFC360`, temporarily sets dimensions
and rotation, calls `ULevel::FarMoveActor` in test mode, then restores the
dimensions, location and rotation. The call at `0xFC4EE` uses ULevel virtual
slot `+0x158`, which resolves to exported `FarMoveActor` at `0xA71C0`; `r9d=1`
is the test argument. It does not independently turn all pawn collision flags
on. A dead pawn has disabled actor collision, so `CanFit` alone is insufficient
evidence of actor clearance. Keep the explicit overlap, BSP floor, slope,
height, reachability, full-body trace, final location, and hazard-zone checks.

No relaxed floor test, unchecked PlayerStart fallback, or claimed successful
revive follows from this audit.

## Pending runtime evidence

The root task is implementing the Game-dispatched death progression. Re-run
the disposable health fixture for instant pit death and non-instant lethal
damage, verify actual faint completion for the latter, one successful safe
placement, and owner resumption. Club/slow presentation and any original
mount/jump state that waits on latent animation remain separate validation
items. Animation completion and placement passing on one host still do not
establish visual quality or two-PC/input acceptance.
