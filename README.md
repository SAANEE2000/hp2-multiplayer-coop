# HP2 M212 Multiplayer

Multiplayer development for Harry Potter and the Chamber of Secrets PC.
The current branch develops the v16 Versus free-for-all mode for 2–8 players;
the separate co-op development copy is preserved.

This repository contains original mod work, narrow patches, build scripts,
documentation and tests. Supply your own HP2/M212 installation and the
`HPVersus_v16_remote_bottom_align_20260905.zip` source archive locally. Retail binaries, game assets and the complete
decompiled source are not redistributed here.

See CURRENT_STATE.md for evidence and outstanding work. A successful compile
does not establish campaign or two-physical-PC compatibility.

On the prepared Windows development PC, double-click `Play-Menu-Test.cmd` to
open a start menu using the original menu art. Versus launches the isolated
`.local/versus-v16-game` build; Single Player and Co-op retain `.local/game`.
The Versus host and join pages expose window X/Y coordinates for same-PC
testing (defaults: host `20,40`, second client `840,40`). Direct launches accept
the same values, for example `JoinVersus.cmd -WindowX 840 -WindowY 40`. After
startup each client receives a normal resizable Windows frame and can be moved
freely; the coordinates only select its initial position. A per-client watcher
restores the frame if the legacy renderer later switches the window back to
popup style, without moving the window again.
The native three-button
Game.exe front-end is preserved for save loading and settings. See
`docs/MENU_TEST_QUICKSTART.md` for setup on another PC.
Co-op server creation offers a new Ch1 test, direct level launch for Ch1–Ch4,
and an honest load screen: co-op save/load is not implemented yet.
The co-op menu starts a dedicated UCC server and a separate local Game client;
closing the local client stops its matching server. This avoids the cutscene
camera-capture failure observed when the earlier menu used a listen server.
See `docs/VERSUS_V16_QUICKSTART.md` for the arena, 2–8 player setup and
the exact tests completed so far.
