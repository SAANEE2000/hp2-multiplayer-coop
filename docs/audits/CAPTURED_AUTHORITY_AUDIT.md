# Captured authority: native execution and measured limits

Audited 2026-09-20 against the local M212 binaries. This report supersedes the
earlier private proposal's assumption that PHYS_None removes every client-side
movement update, and its assumption that simulated PlayerTick polls throughout
the owner's Role2 interval. No proprietary source or disassembly is reproduced.

The opt-in first-Ch1-intro run demonstrates real authority walking and original
cue completion. It does **not** establish continuous owner camera rendering,
physical input acceptance, or a production-ready scene lifecycle.

## Binary identity

All native addresses below are RVAs, independent of ASLR. Preferred image base
for these binaries is `0x180000000`.

| Binary | SHA256 |
| --- | --- |
| Engine.dll | `e7bd8f53aa1bce2386ba8943fdfc4d4c54c0a27948f49bc0de53dee22cc82391` |
| Core.dll | `40281c82e47e8e76828cb64736136cf1deafd5bd51ad42cb88c06078db687e27` |

## Authority execution

Engine `AActor::Tick` starts at `AF4A0`. The Role4/RemoteRole3 test at
`B015A..B0175` selects a remote-autonomous branch whose jump `B039E→B07C5` skips
ordinary script tick, ProcessState and performPhysics. Timers and earlier native
animation processing are separate; they do not execute the latent state body.

Keeping authority Role4 and changing RemoteRole to2 for the captured scene reaches
the ordinary ProcessState call at `B054C` and the physics call at `B0796`. The
prototype supplies no second Game-driven physics call. Engine ProcessState
`101B50` polls the pending latent action at `101BD5..101BF6` and steps state
bytecode at `101C2D..101C38`. Native MoveTo `CF510` installs action501 at `CF617`;
PollMoveTo `CF6E0` evaluates the original movement and clears the action on
completion. AutonomousPhysics `D9AF0` calls physics, not ProcessState, so it is
not an equivalent replacement for this state execution.

Core `UObject::GotoLabel`, RVA `73780`, searches the current state and follows
SuperField at `73836→737C7`. It installs the ancestor label's script node/code at
`7380E..73825`. This permits a child state to override completion validation while
retaining the original Begin/Loop. The successful Ch1 run exercises that path.

## Role delivery and owner identity

Engine ReplicateActor `127050` reads/saves RemoteRole at `1273FC`; its conditional
per-connection downgrade only starts when that value is3. It does not promote an
explicit2 back to3 merely because the connection owns the pawn. The optimized
property list detects RemoteRole changes at `6BCB1..6BD3E`. Serialization swaps
Role/RemoteRole property identifiers at `127840..1278CB`, so authority RemoteRole2
is delivered as client Role2.

Initial HandleClientPlayer `12B0C0` explicitly writes Role3 at `12B177`, binds the
viewport, and changes connection State2 to State3 at `12B1FA`. ReceivedBunch only
uses that initial path while State2; ordinary subsequent role properties do not
repossess the pawn. Waiting for established owner readiness before capture is
therefore part of the contract.

## Correction: the client's Role2 branch is different

The client pawn's local Role2 selects an **earlier** branch in AActor::Tick:

| RVA | Behavior |
| --- | --- |
| `AF780..AF7AA` | Recognizes the pawn flag and local Role2; records the simulated-pawn branch selector. |
| `AF8B7..AF8C0` | Enters that branch after animation handling. |
| `AFADC..AFB1B` | Calculates Velocity multiplied by DeltaTime and calls exported `AActor::moveSmooth` at `D9BE0`. This call does not depend on Physics being nonzero. |
| `AFB20..AFB72` | Tests/dispatches the ordinary script Tick event, not PlayerTick. |
| `AFB7B→B07BE` | Bypasses the later PlayerTick, ProcessState and ordinary performPhysics path. |

Consequently, PHYS_None prevents neither this normal simulated extrapolation nor
network PostNetReceive transform reconciliation. These are distinct from a second
input-driven ReplicateMove/AutonomousPhysics call. The source guards suppress
owner input, but the run has no native-call counter proving all movement clocks.

The prototype's simulated Tick body is empty. Its helper is called by PlayerTick
and lifecycle RPCs, so it is **not continuously polled in the Role2 branch**.
When release arrives while Role2 is still installed, the simulated release RPC
can run the helper once. After Role3 arrives, ordinary PlayerTick resumes the
handoff. Future timeouts/monitoring must use the actual simulated Tick or a
separate owner actor; merely marking PlayerTick simulated does not select it.

Camera calculation has a separate native Draw→PlayerCalcView dispatch. Keeping
the override simulated allows Role2 execution; the held-view branch retains a
valid shared snapshot after source bCaptured clears. It currently returns before
the shared-view diagnostic log, so absent owner shared-view lines do not establish
either camera success or failure. Rendered presentation needs direct validation.

## Runtime evidence

Build `20260920-175239-291` reports 0 errors and268 warnings. It records dirty
source, so the associated source commit is not an exact clean-build claim.
Host and both client launch records agree on HGame SHA256
`774509e44df2c806acd2009c1be75aecae4633a824c8f745a2a305797c025a31`
and M212Share SHA256
`d05570d425c603e6180c54aaac864e1fee2bb170321680287b53442883391d9c`.

The host run is `coop-host-20260920-175338-368-c9fc4f`. Its server-stdout lines
313..359 show original stateMovingToLoc, the RemoteRole3→2 boundary, intermediate
positions toward CutMark0, original completion after462.404694 XY units, and
receipt of `_2UniqueCue`. Final XY error is0.095703. Lines389..401 show successful
walk evidence at release and accepted resume serial2/floor63.928154. The
diagnostic disables both original snap fallback and the separate CutBypass snap;
the observed trajectory is not inferred only from the endpoint.

Canonical owner run `coop-join-20260920-175338-626-92a8fd`, engine-0.log:

- Line1387: owner-held, serial1, Role3, Physics0, at the start.
- Line1388: owner-simulated, **serial2**, Role2, Physics0, already at the endpoint.
  This is a release-RPC observation, not an earlier continuous polling record.
- Line1389: observed Role3, endpoint reconciliation, resume request serial2.
- Lines1390..1392: fresh HUD status, local capture released, owner-resumed Role3.

Companion run `coop-join-20260920-175347-587-184d25` logs capture, shared-view
scene1/snapshot42 and release at lines1376..1378. It has no per-scene readiness
ACK and no continuous camera samples. Both clients end with UDP error10054 after
these completion records; the logs alone do not prove graceful shutdown cause.

Server script warnings remain, including legacy Harry initialization and
orangesnail.EndTrail accesses. This is a narrow movement/handoff PASS, not a clean
runtime or full M1 PASS. Packet loss, rollback, captured death/disconnect,
simultaneous scene readiness, repeat/reentry handling, and physical two-PC
camera/input acceptance remain unverified.
