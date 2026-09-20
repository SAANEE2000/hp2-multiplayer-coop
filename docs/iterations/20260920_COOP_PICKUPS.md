# Personal pickups and save entry guards

Commit: commit containing this report; build-time HEAD `5867b1d`, sourceDirty=true.
Branch: `coop`.
Changed files: HPCoopPersonalPickup, HPCoopPickupProbe, Game/launcher probe gate,
coop-personal-pickup and coop-save-load-guards recipes.

Why: original HProp awards its cached canonical Harry. Original SavePoint also
mutates its book and canonical health before attempting an unsupported save.
The new narrow pickup adapter awards the registered actual touching owner once;
save guards reject audited book/menu entries before their side effects. Original
single-player/Versus bodies remain after co-op-only guards.

Build: **PASS**, `20260920-180631-074`, UCC 0 errors / 268 warnings.

- HGame SHA256: `96cf41f335d4e77f45eb81728ba5733c7fbd638186fdb87805ef8d2879acb788`.
- M212Share SHA256: `819c566a0cd6fee8bce984bd237fc5d3037db10910a8a418c84e2b08d68a15ff`.
- Source manifest/UCC log: `.local/builds/20260920-180631-074/`.
- Host: `coop-host-20260920-180709-151-ec1695`.
- Clients: `coop-join-20260920-180709-413-33c715` and
  `coop-join-20260920-180717-338-e39424`.

Automated/local tests:

- Actual recipe chain validated 17 files. Recipe suite: 19 tests,
  **18 PASS / 1 SKIP** (Windows symlink privilege). Fresh, intermediate and repeated
  application are covered. An initial wrong test filename ran zero tests; the
  corrected test_patch_recipes invocation above is the counted result.
- Initial UCC failed the fixture's TouchingActors out-parameter type. Both typed
  iterators now use HPCoopHarry; subsequent UCC builds passed.
- Initial runtime refused Arm. A diagnostic server proved omitted Spawn Tag was
  None despite the class default. Game now explicitly supplies the unique fixture
  event tag, and Arm rejects any other tag before searching for conflicts.
- **PASS phases1–6:** six exact original prop instances entered stationary owners
  through native MoveSmooth/Touch. Each produced one original event with original
  arguments, one personal award and destruction; cached PlayerHarry was unchanged.
  Both frogs gave 20→60 HP, both bottles gave 0→1 potion without healing. Repeated
  synthetic dead/captured contacts refused without consuming or granting; the same
  props granted once after clearing those synchronous fixture flags.
- **PASS phases7–9:** two active original one-shot SavePoints each received two
  fresh native contacts. Four matching real SavePoint.Touch guard records identify
  the proper toucher. Both books retained activation, opacity, collision, timer,
  canonical alias and existence; both player counts/save queues stayed unchanged,
  including a delayed verification before fixture cleanup.
- **PASS owner snapshots:** all five server revisions per slot match that client's
  applied health/potions. Final fixture values are slot0=100HP/1 potion and
  slot1=60HP/2 potions. Collected clients have zero Accessed None/Critical errors.
  Evidence: `.local/pickup-status-verification-180631.json`.

Confirmed working: executed server contact ownership, single-commit event/grant,
snapshot isolation and book refusal predicates in this disposable loopback run.
The fixture seeds inventory and freezes only synthetic prop motion; it is not
ordinary navigation, a simultaneous race, real death/capture or a checkpoint test.

2-PC tests required: natural placed pickups, owner/proxy HUD/audio/vanishing,
concurrent collection, menu save/load refusals, normal interaction after refusal.
Unconfirmed: placed actor replication, all other collectibles, shared persistence,
native frontend/typed Exec paths, SP and Versus runtime regression acceptance.
Known limitations: original map-Harry/snail warnings remain; immediate pickup
destruction does not preserve the original single-player HUD flight animation.
These changes are newer than the supplied `60f6173` two-PC kit.

Next step: verify placed-item network lifecycle, harden first-intro readiness and
failure boundaries, and implement original ledge movement. Milestone 1 remains open.
