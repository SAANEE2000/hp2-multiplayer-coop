# Ch1 → Entryhall_hub: native travel probe (20 September 2026)

This is an opt-in diagnostic, not campaign travel or a save/load implementation.
It starts from the completed original Ch1 intro in the two-player dedicated
`RictusempraLessonComplete` fixture, then calls native `Level.ServerTravel` once.
The normal launcher does not enable `CoopProbe=Travel`.

The first local host + two client run (`230906-626-43230f`) proved that both
clients automatically open `Entryhall_hub`, but the destination rejected their
logins: no coherent initial campaign snapshot. The second run
(`231546-054-45d73d`) showed that relative travel inherits source-only URL
options, including the Ch1 test stage; the probe now explicitly clears them.
The third run (`232115-717-6b6fcc`) reached destination `InitGame` with clean
options and native `?GameState=GSTATE030`, yet still rejected both logins.
A one-per-map capture diagnostic in run `232740-160-fe07eb` identified the
precise mismatch: hub map Harry had string `GSTATE030`, numeric index `0`,
and only three base spells. `HPCoopCampaignState.IsSnapshotReady()` correctly
returned false. Native `GameState` updates the string before screening, but
does not populate the cache or spellbook.

The probe now transfers a 32-slot mask for the game's ten known spell classes
through the server-controlled travel URL. It refuses unsupported spells and
checks the base spells; destination `InitGame` validates the 32 characters,
state token, source/destination map, dedicated mode, and absence of source
fixtures before setting the map Harry's index and spellbook. The ordinary
`CaptureFrom`/`IsSnapshotReady` gate then runs unchanged. This is restricted to
`Ch1Rictusempra → Entryhall_hub`; inherited transfer options on another map
are rejected rather than silently reused.

With this handoff, the local run `233237-212-218134` and final runtime check
`233808-510-e1fb76` both completed the original intro, moved both clients
automatically to the hub, captured `GSTATE030/index 30/four spells/ready=True`,
accepted two distinct destination pawns, and obtained server context-ready
and local context-ready for both. The final check used client sessions
`233820-651-dd7273` and `233831-883-8b3aff`; each reported
`local-initial-state=GSTATE030 spells=4 test-stage=False`. No login failure or
Critical appeared in these three engine logs. All processes were verified by
path and start time, stopped, and their logs collected under `.local/runs`.

This is **not a hub gameplay PASS**. Both clients still log native
`Can't find a valid player` during early map screening; the late owner snapshot
does not repair that pass. The server then runs the original hub scene
`LevelStart_EntryHallHub_GState03`, which reports missing teleport locations
`BlockActorOnMark1/2`, blank cues, and failed BlockActor release. The two
marker names do not appear in the installed `Entryhall_hub.unr` name table or
other installed map name tables (ASCII search); this is a content discrepancy
to investigate, not grounds to delete the commands. The server also had 145
`Accessed None` warnings in the final run, chiefly the original CutScript
null captured-actor path. The co-op disk-script subclass now handles logging
on a headless server for all file-backed scenes and always records errors,
removing console-related warnings while preserving the semantic errors.

The handoff currently transfers only story string/index and spell classes.
Health/status, cards, points, objectives, persistent characters, checkpoint,
save identity, and revisions are not transferred. It does not reproduce the
original `SavePActors`, `PreClientTravel`, `TravelPostAccept`, or SmartStart
cycle. Two physical PCs, visual world equivalence, hub cutscene completion,
real campaign transitions, save/load, and Versus remain open gates. The
previous clean private two-PC kit is still the intro-only package; this
diagnostic build has not been exported to it.

Validation: UCC 0 errors / 268 baseline warnings after each code iteration;
`python tests/test_patch_recipes.py` 19 tests, 1 Windows symlink skip;
`git diff --check` clean. The final preflight guard tightening was compiled
after the last runtime check but does not have a fresh runtime observation.
