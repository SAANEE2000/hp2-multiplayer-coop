# Original Lumos contact and owner lifetime

Commit: commit containing this report; build-time HEAD `051f81e`, sourceDirty=true.
Branch: `coop`.
Changed files: HPCoopLumosProbe, spell-contact-diagnostics recipe, audit follow-up.

Why: the first two-owner fixture spawned both original spells but observed only
the first hit. New opt-in logs in original baseSpell HitWall/ProcessTouch/Destroyed
showed spellLumos1 hitting BSP at `(636.388916,-2846.373535,-49.864784)`.
The fixture had checked point LOS, which did not guarantee clearance for a
projectile with a two-unit collision radius/height. Its candidate search now uses
the original spell's collision extent. No hit is synthesized, collision disabled,
target substituted or trajectory/handler changed.

Build: **PASS**, `20260920-174112-409`, UCC 0 errors / 268 warnings.

- HGame SHA256: `c394dc91430112f5cf2e8964fc165d098bba4556a8697e2d0a32bfae533ba339`.
- M212Share SHA256: `f9bf4e0b2472f8aca44c133b6bd7d443942d13fd873ba6f9187349cceb6af763`.
- Source manifest/UCC log: `.local/builds/20260920-174112-409/`.

Automated/local tests:

- Patch recipes: 19 tests, **18 PASS / 1 SKIP** (Windows symlink privilege).
  Actual build application/reapplication verified 13 complete file hash chains.
- Negative diagnostic run: `coop-host-20260920-173859-501-40a477`, build
  `20260920-173805-655`. First spell touched gargoyle0; second hit BSP and was
  destroyed. The original second-hit timeout was a real failure of that fixture.
- Passing server: `coop-host-20260920-174157-743-3d153b`.
- Clients: `coop-join-20260920-174158-002-8c9042` and
  `coop-join-20260920-174206-446-795c56`.
- **PASS**: ordinary ServerCastCoopSpell validation spawned exact spellLumos for
  each registered owner, then original ProcessTouch hit actual map gargoyle0 and
  gargoyle3. Both targets entered Green and activated distinct original lights
  owned by the corresponding wands/players.
- **PASS**: both lights active, slot 0 explicitly switched off while slot 1
  stayed active, then slot 1 switched off at the original 30-second expiry.
- Collected client logs: zero Accessed None/Critical, one capture release each.

2-PC tests required: owner and observer FX, input/aiming, natural access to the
gargoyles, reveal geometry and shared LumosTrigger doors, moving while lit,
recasting, death/disconnect and network loss. These remain NOT RUN.

Confirmed working: original server projectile contact, correct two-owner
activation, isolated off and original finite lifetime in this loopback fixture.
Unconfirmed: rendered light/animation parity, puzzle traversal and campaign.
The fixture temporarily moves and restores authority pawns within a synchronous
call to reach checked firing positions; it is not a natural gameplay test.

Known regressions/limitations: legacy map Harry/snail server warnings remain.
No SP or Versus runtime pass is claimed; the base recipe only logs when the
existing bUseDebugMode flag is enabled. Normal gameplay does not enable it.

Next step: original scripted walk under an explicit authority mode, then
personal pickups and checkpoint/menu guards. Milestone 1 remains open.
