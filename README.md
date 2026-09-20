# HP2 M212 Multiplayer

Campaign co-op development for Harry Potter and the Chamber of Secrets PC.
Co-op has priority; Versus and Hide & Seek reference implementations are preserved.

This repository contains original mod work, narrow patches, build scripts,
documentation and tests. Supply your own HP2/M212 installation and the supplied
v18 source snapshot locally. Retail binaries, game assets and the complete
decompiled source are not redistributed here.

See CURRENT_STATE.md for evidence and outstanding work. A successful compile
does not establish campaign or two-physical-PC compatibility.

On the prepared Windows development PC, double-click `Play-Menu-Test.cmd` to
open a start menu using the original menu art, with Single Player, Co-op and
Versus routes into the verified `.local/game` copy. The native three-button
Game.exe front-end is preserved for save loading and settings. See
`docs/MENU_TEST_QUICKSTART.md` for setup on another PC.
Co-op server creation offers a new Ch1 test, direct level launch for Ch1–Ch4,
and an honest load screen: co-op save/load is not implemented yet.
