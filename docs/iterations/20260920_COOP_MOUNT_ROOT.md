# Original climb32 state flow: B0/B1 diagnostic

Branch: `coop`. `MountRootB0/B1` are disposable, explicit Ch1 diagnostics.
They require a fresh `RictusempraLessonComplete` map, dedicated host, both
owners, `CapturedAuthorityDiagnostic` and normal `FirstIntroPreflight`.
Ordinary sessions still use `HPCoopHarry`; the trial subclass never replaces
it unless one of these two options is selected. Neither fixture uses a
collision-selected ledge or enters from `ServerMove`/`OldMove`.

The probe waits for the **original** first intro to complete and both players
to resume. Both clients validate the actual mesh bone names and acknowledge.
The fixture verifies an existing clear capsule volume, holds the owner's
input, then calls one inherited `Mount(30 forward + 32 up)` on authority.
Original `Mounting`/`MountFinish` latent code, animation, capsule mutation
and native tick run without a copied phase implementation. A final endpoint
correction is logged separately from the uncorrected receiver. B0 leaves
`bAnimMove` false on the receiving Role2 pawn; B1 sets only that bit for the
received climb sequence. Bone polling on clients is diagnostic and may change
animation-cache timing.

Runtime build `20260920-212750-350`: UCC **0 errors / 268 warnings**;
HGame SHA256 `63cabcb5f71f119a71d0b38070b0e8cb3df931359e53efde240679216549f9e9`,
M212Share SHA256 `7807a0c9a4c327d07005bfb81b2af0158b730ceae65f5cbf2e3cc0830180873b`.
After adding a launcher/Game guard requiring the normal first-intro preflight,
final build `20260920-213510-881` also passed UCC 0/268;
HGame `1da75269558ec0b186a1068db3101a03db48b087a6e7af05a343c9607c12c659`,
M212Share `b16fd39d1ea8f72a5fd43c55e7fcb35fdd3a019e9c01aaac18dc7b34efd9a7c6`.
Launcher `PrepareOnly` accepted the full explicit combination and rejected
MountRoot without FirstIntroPreflight.

| Evidence | B0 | B1 |
|---|---:|---:|
| Host session | `coop-host-20260920-212956-288-e7298a` | `coop-host-20260920-213148-100-d1dff9` |
| Intro completed, both bone ACKs | yes | yes |
| Original Mounting, shrink, restore, PlayerWalking | one each | one each |
| Native `MountFinish.PlayerTick` calls / duplicate calls | 140 / 0 | 140 / 0 |
| Server final physics | Falling | Falling |
| Owner observed Role2 and accepted endpoint | yes | yes |
| Owner actor error **before** endpoint correction | 61.03 units | 60.47 units |
| Companion's `climb32` root-local sample count | 17 | 20 |
| Companion root-local X range | −8.970 to 24.017 | −0.043 to −0.043 |
| Companion root-local Z range | −15.276 to 27.659 | −4.568 to −4.568 |
| Companion samples with `bAnimMove=True` | 0 | 20 |

Both owners printed `owner-committed` after the server accepted resume.
Both client logs had zero Critical/Accessed None. Each server had zero
Critical and two known legacy map-Harry `PreBeginPlay` Accessed None warnings.
All six owned processes were stopped and their logs collected. The server's
scripted residual callback measured zero displacement *inside that callback*;
the original state still moved the actor. Native root-consume/collision
adjustment calls were **not** traced, so callback count and distance cannot
be presented as an exact native root-motion accounting.

Two earlier B0 attempts stopped safely at the first-intro camera ACK gate:
the second local client never obtained a shared-view snapshot within the
deadline. A subsequent B0 attempt passed that same gate, so this is an
intermittent local delivery/presentation issue to investigate, not an
accepted normal path. Another B0 attempt reached the mount hold but a
diagnostic check incorrectly required `AnimRate=0` after `PlayAnim('None')`.
M212 clears sequence/root-motion while retaining the previous numeric rate;
the check was corrected, then B0 and B1 reached the results above.

B1's constant sampled root-relative position is useful evidence about the
receiver's mesh transform, **not** a visual pass: `BonePos` can evaluate the
mesh and affect cache timing. B1 did not fix the roughly 60-unit actor drift.
The final endpoint correction cannot hide that during-play discrepancy.
Grounded ledge completion, collision-selected entry, old packet replay,
visual camera/feet, repeat without bone polling, interruptions and two
physical PCs remain untested. The diagnostic is off by default and should
not be used as a campaign progression or save session.
