// Network-visible Padlock with the untouched stock HAlohomora callback:
// HandleSpellAlohomora -> OnAlohomoraExplode -> TriggerEvent -> Destroy.
class HPVersusArenaLock extends Padlock;

defaultproperties
{
    bStatic=False
    bNoDelete=False
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
}
