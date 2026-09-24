// Stock spellTrigger logic with an explicit Alohomora filter.
class HPVersusArenaAlohomoraTrigger extends spellTrigger;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    SetCollision(True, False, False);
}

defaultproperties
{
    bInitiallyActive=True
    bTriggerOnceOnly=True
    eVulnerableToSpell=SPELL_Alohomora
    CollisionRadius=30.0
    CollisionHeight=45.0
    bCollideActors=True
    bProjTarget=True
    bStatic=False
    bNoDelete=False
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
}
