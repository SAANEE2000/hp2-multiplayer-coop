# Current state — 2026-09-20

- Initial import: the 874 installed HGame class files are byte-identical to v18.
- v18 is the latest supplied candidate, not a verified working release.
- Handoff evidence: v15 has paired runtime movement logs; v16 adds an unverified
  remote render alignment change; v7 direct movement remains a reference.
- Original HPCoopGame is a stub, not campaign co-op. Its local variable declaration
  inside an if block is incompatible with the compiler grammar.
- Baseline binaries, archives and sources remain untouched and excluded from Git.
- Initial build, upstream comparison and co-op foundation are in progress.
- main must not be described as a verified gameplay release before runtime tests.
- Full campaign, two-PC acceptance and Versus completion are NOT confirmed.
