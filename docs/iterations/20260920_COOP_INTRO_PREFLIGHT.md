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

Known remaining integration issues: failure cleanup needs an explicit owner ACK
and fresh status delivery after Role3; its completed owner watchdog must stop.
Missing ACK, death, disconnect, blocked walk and release timeout need runtime
evidence before enabling this policy in ordinary play.

Next step: integrate the reviewed failure-cleanup follow-up and exercise negative
paths. The user kit `60f6173` predates this change.
