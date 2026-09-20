# First Ch1 native captured walk

Commit: commit containing this report; build-time HEAD `60f6173`, sourceDirty=true.
Branch: `coop`.
Changed files: HPCoopGame, HPCoopHarry, HPCoopCutScriptDisk, launcher.

Why: original asynchronous `Harry walkto cutmark0 *` did not move the remote
authority pawn. On the supplied M212 engine, Authority/AutonomousProxy skips the
normal native state executor and physics. Scene completion alone was insufficient
evidence because the script did not wait for that walk's cue.

The explicit `-CapturedAuthorityDiagnostic` flag is limited to the first Ch1
capture, dedicated lesson-complete test stage, and no simultaneous runtime probe.
After the owner's capture ACK, the server changes RemoteRole to SimulatedProxy
for the captured operation. The original state/latent MoveTo/native physics then
execute on the same possessed registered Harry. No replacement walk, server
teleport, synthetic completion cue or extra AutonomousPhysics call is introduced.
Original movement completion and actual CutScript cue receipt are observed.
Both original snap fallback and diagnostic CutBypass teleport are disabled.

Release restores the previous role, holds input until owner Role3 is observed,
reconciles that owner's actual authority endpoint, clears prediction, and sets a
fresh validated timestamp floor before accepting movement again. Owner/camera
helpers and role-transition RPCs use simulated execution where required.

Build: **PASS**, `20260920-175239-291`, UCC 0 errors / 268 warnings.

- HGame SHA256: `774509e44df2c806acd2009c1be75aecae4633a824c8f745a2a305797c025a31`.
- M212Share SHA256: `d05570d425c603e6180c54aaac864e1fee2bb170321680287b53442883391d9c`.
- Full source manifest/logs: `.local/builds/20260920-175239-291/`.
- Server: `coop-host-20260920-175338-368-c9fc4f`.
- Clients: `coop-join-20260920-175338-626-92a8fd`,
  `coop-join-20260920-175347-587-184d25`.

Automated/local tests:

- Launcher default-off and valid diagnostic preparation passed. Join, missing
  test stage and simultaneous Health probe were rejected before launching.
- **PASS, server:** intermediate native walking samples at RemoteRole2,
  original stateMovingToLoc/PHYS_Walking, X approximately 4726 through 4285.
  Original Done reports 462.404694 units displacement and 0.095703 XY error at
  `(4280.418945,-27.838644,-723.275757)`. Exactly one original cue was observed.
- **PASS, boundary observations:** owner-held Role3/PHYS_None, owner-simulated
  Role2/PHYS_None, restored Role3, server resume floor 63.928154, owner resumed.
  The Role2 observation occurs in release serial2, so it does **not** establish
  continuous owner polling or physics throughout capture.
- Both clients logged one local capture and release. No client Accessed None or
  Critical errors. UDP10054 followed deliberate server shutdown. Legacy server
  map-Harry/snail warnings remain; this is not a warning-free runtime.

Confirmed working: native canonical walk, original completion/cue, bounded role
handoff and release handshake in one loopback session.
Unconfirmed: continuous/rendered camera, owner/proxy animations, actual resumed
keyboard input, stale/lost packet injection and physical two-PC behavior.

Known limitations: default-off diagnostic only; companion has no per-scene ACK
barrier; captured death/disconnect, timeout recovery, nested/repeated scenes,
falling/movers/mounting and travel are not covered. A diagnostic failure can leave
an owner held and requires ending that disposable session. SP/Versus runtime
regression checks have not been performed. The separately supplied `60f6173`
two-PC kit predates and does not contain this diagnostic.

Next step: personal pickup ownership and early save/load guards, then bounded
product hardening of capture and original special movement. Milestone 1 is open.
