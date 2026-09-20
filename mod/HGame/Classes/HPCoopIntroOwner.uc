// Client-local watchdog: a real Actor Tick, independent of pawn Role/state.
// It never performs physics, advances a cutscript, or changes network roles.
class HPCoopIntroOwner extends Actor;
var HPCoopHarry LocalHarry;

event Tick(float DeltaTime)
{
    if (LocalHarry == None || LocalHarry.bDeleteMe || !LocalHarry.IsLocalCoopPlayer())
    {
        Destroy();
        return;
    }
    LocalHarry.PollCoopIntroOwner();
    if (!LocalHarry.bCoopIntroLocalFailed) LocalHarry.CoopSceneOwnerTick();
    if (!LocalHarry.bCoopIntroLocalActive) Destroy();
}

defaultproperties
{
    RemoteRole=ROLE_None
    bHidden=True
    Physics=PHYS_None
    bCollideActors=False
    bCollideWorld=False
}
