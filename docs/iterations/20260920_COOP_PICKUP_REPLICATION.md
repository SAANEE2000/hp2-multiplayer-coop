# Original pickup replicas on both clients

Commit: commit containing this report; build-time HEAD `749dabc`, sourceDirty=true.
Branch: `coop`.
Changed files: PickupNetProbe, local PickupObserver, owner observation RPCs,
Game/launcher opt-in selection and parent fixture option hook.

Why: the prior synchronous contact fixture could create and destroy a prop before
either client received its actor channel. Correct inventory snapshots did not
prove removal of an existing network replica.

Build: **PASS**, `20260920-182426-014`, UCC 0 errors / 268 warnings.

- HGame SHA256: `de047bb72d22e39a7ddfea7d1cca8c141ff5bca07fca63e1b0f34356992b5492`.
- M212Share SHA256: `ba7263f129b5b6e82ba79f0131532b95f73e89a0c7d4c707bc85f34d3c7dbcb4`.
- Host: `coop-host-20260920-182533-248-049452`.
- Clients: `coop-join-20260920-182533-515-50b2e2` and
  `coop-join-20260920-182541-954-75a58e`.

Automated/local tests:

- **PASS:** two owners observed the same original ChocolateFrog actor reference
  before contact, each as a visible collidable Role2 replica. A native contact
  awarded slot1 40HP exactly once, then both clients observed the previous actor
  absent, including a two-second late check.
- **PASS:** repeated independently for original WWellBlueBottle. Slot0 received
  one potion without healing. Both clients observed that bottle, then its native
  disappearance and stable absence.
- Item bAlwaysRelevant stayed False. No relevance/RemoteRole/ownership change,
  client hiding/deletion, forced frame, or direct Touch call was used.
- Three status revisions per owner matched the corresponding server slot;
  client logs contain zero Accessed None/Critical errors. Local names differ from
  the server's names, so correlation used Actor references before retaining the
  observed client Name/Class. Evidence:
  `.local/pickup-net-verification-182426.json`.
- A preceding one-frog run also passed on build182028-146; this later run is the
  counted two-class result. Source manifest and full UCC log are preserved.

Confirmed working: two original-class network replicas actually existed before
the real server pickup and disappeared on both clients through native lifetime.
The observer is read-only; ordinary play never spawns or arms it.

Unconfirmed / 2-PC tests required: natural placed-map items, hopping, rendering,
sound, input, simultaneous contact races, latency/loss, full collectible policy
and persistent inventory. The fixture seeds status and freezes only synthetic
prop motion. It is discarded after the run. Legacy map-Harry/snail server warnings
remain. No new SP/Versus runtime acceptance is claimed for this test-only addition.

Next step: first-intro readiness/failure boundaries, original ledge mechanics and
two-target Ch1 enemy integration. The user kit `60f6173` predates these changes.
