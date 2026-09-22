# Startup.unr: Versus spawn points

The local test map at `.local/versus-v16-game/Maps/startup.unr` has eight
`HPVersusStart` actors with `VersusSpawnIndex` 0 through 7. The supplied retail
map is unchanged and is not distributed in this repository.

To reproduce the map edit on a local copy of `Startup.unr`, build `HGame.u`
first, then open that copy in UnrealEd. The base map must already contain
`HPVersusStart0` and `HPVersusStart1`. Choose **File → Import**, select
`patches/startup-versus-spawns-2-to-7.t3d` as **Unreal Text (*.t3d)**, enable
**Import into existing map**, and save the map. Import the patch only once;
repeating the import would duplicate the six actors.

The six added points occupy three rows at Y = 300, 0 and -300, with X = -128
and 128. Their Z is 122.5. The original two starts remain at approximately
(1, 500, 96) and (1, -500, 96).

The v16 Versus mode now assigns unique slots 0–7, checks start occupancy,
rejects a ninth connection and reuses a slot after the server closes the old
connection. Eight connected clients passed this loopback test; eight-player
combat and visual spawn safety on two physical PCs remain unverified.
