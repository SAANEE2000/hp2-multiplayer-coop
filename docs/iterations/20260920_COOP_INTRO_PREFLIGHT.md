# First intro: both owners before original Play

Commit: commit containing this report; build-time HEAD `b1c4951`, sourceDirty=true.
Branch: `coop`.
Changed files: IntroCoordinator/IntroOwner, Game/Harry hooks, two-file source
recipe and explicit launcher flag `-FirstIntroPreflight`.

Why: captured native walking alone did not prove that both owners were ready
before the scene changed the world. The new opt-in first-intro gate precedes
original Play's counter/thread creation. Both owners must acknowledge a held
camera dispatch; original Capture must precede the canonical Role2 handoff.
The original interpreter, walk, cue and release remain responsible for progress.
Each next CutScript command checks the gate, including reentrant failure.

Build: **PASS**, `20260920-184147-517`, UCC 0 errors / 268 warnings.

- HGame SHA256: `75ecfea485bcbcd1c30afe78c203418f827693fac2eead5ef5166648c2483de7`.
- M212Share SHA256: `18cdcb85ca8f6cda714393958431227d8de74227c3c28a2c76df8fbcd363a9bf`.
- Host: `coop-host-20260920-184227-690-720efc`.
- Owners: `coop-join-20260920-184227-963-73b8ed` and
  `coop-join-20260920-184236-911-33dc5f`.

Automated/local tests:

- Recipe tests: 18 passed, one Windows symlink-privilege skip. All actual recipes
  passed clean, intermediate and repeated application checks. Build verified 19
  source hash chains. Launcher accepts the explicit diagnostic combination and
  rejects FirstIntroPreflight without CapturedAuthorityDiagnostic.
- Both ready records precede the single original Ch1RictuIntro Play. The original
  canonical walk moved 462.497955 units, ended 0.002443 XY units from CutMark0 and
  delivered its original cue. Exactly one original BeginChallenge was issued.
- Both independent resume ACKs preceded coordinator completion. Both owners
  logged completion as Role3. The leader produced continuous Role2 owner pulses
  and held-view PlayerCalcView calls; the companion remained Role3. Each had 51
  owner pulses, over 7,000 camera calls and advancing shared snapshots.
- Both client logs: zero Critical/Accessed None. Server: zero Critical and 158
  legacy Accessed None warnings, which remain unresolved. Evidence assertions:
  `.local/intro-verification-184147.json`. All three processes stopped and logs
  collected before the next change.

Confirmed working: this opt-in normal path on one PC with two actual network
clients, including original authority movement and both owner handshakes.
Camera evidence is dispatch evidence, not a screenshot or input acceptance.

Unconfirmed / 2-PC tests required: rendered view, sound, input restoration,
packet loss/latency, all negative paths and later scenes. The flag remains off by
default and requires fresh Ch1 lesson-complete/captured diagnostics. Skip is
intentionally refused for this scene. Terminal failure requests a fresh host;
it does not roll back world changes, recover a checkpoint or transfer captures.

Follow-up build: **PASS**, `20260920-204845-541`, UCC 0 errors / 268 warnings.
HGame `18e0f346128aa1ee2809135652907ba96bc9b3610dcc54eac5fa8130567286e0`;
M212Share `313c7ffa56da67f41a5ee6fe06dcfa29cc7b2b6034022155e8b20d0b7bb57f4a`.
The failure path now waits for each surviving owner to observe real Role3,
restore its camera and send one serial checked cleanup ACK. Authority then sends
a fresh personal health/status snapshot. The local watchdog stops after cleanup;
terminal input hold stays in place.

Explicit disposable negative tests on that exact build:

- `MissingAck0` and `MissingAck1`: the server discarded a valid owner report
  for one selected slot. In each run the other slot was ready, but the original
  scene remained `played=0`, `threads=0`, `playing=False`. No BeginChallenge ran;
  both owners acknowledged terminal cleanup after the 20 second preflight bound.
- `DuplicateCallbacks`: a stale serial, repeated valid capture callback and
  duplicate Play did not change the ready count, counter, threads or timestamps.
  The subsequent original scene and BeginChallenge ran once; both owners
  completed their resume barrier.
- `DeathWalk0` / `DeathWalk1`: the real co-op KillHarry callback ran after
  canonical MoveTo had moved 1.18 / 1.15 XY units. Each run held phase 6 with
  `played=1`, four original threads and no subsequent CutScript command,
  BeginChallenge, ForceFinish or completion. The dead and surviving owners both
  confirmed cleanup; their fresh status revisions were logged.
- A separate process termination during the walk was detected after the native
  walk had already completed, owing to the normal 15 second connection timeout.
  It still failed before scene completion: disconnected slot unavailable,
  surviving owner cleanup ACK, no later CutScript command. This does **not**
  establish server handling of a disconnect detected during the native walk.
- A disposable INI with a 2 second connection timeout caused a missing ACK
  before Play. Both owners cleaned up with `played=0`. This was a network timeout
  fixture, not a walk-disconnect test.

The five explicit fixture runs had zero client Critical/Accessed None; each
server had zero Critical and 158 known Accessed None warnings. Exact session IDs,
counter checks and log evidence are in `.local/intro-negative-verification-204845.json`
and `.local/intro-disconnect-verification-184632.json`; all processes were stopped
and logs collected. `CoopIntroFault` is accepted only with explicit
`FirstIntroPreflight` and remains off in ordinary play.

Still required before ordinary play: genuine blocked walk, disconnect delivered
mid-walk, release timeout, pause/skip attempts, visual camera and input on two
physical PCs, later scenes and world rollback/recovery. Terminal failure still
requires leaving the host; checkpoint reload is not implemented. The original
script may already have modified other world actors before a late failure.

Next step: two-PC visual/input check and original ledge/AI work. The user kit
`60f6173` predates this change.
