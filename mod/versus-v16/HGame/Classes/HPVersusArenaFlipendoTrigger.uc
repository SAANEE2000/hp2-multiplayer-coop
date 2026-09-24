// Stock spellTrigger logic with an explicit Flipendo filter.
class HPVersusArenaFlipendoTrigger extends spellTrigger;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    SetCollision(True, False, False);
}

defaultproperties
{
    bInitiallyActive=True
    bTriggerOnceOnly=True
    eVulnerableToSpell=SPELL_Flipendo
    CollisionRadius=30.0
    CollisionHeight=45.0
    bCollideActors=True
    bProjTarget=True
    bStatic=False
    bNoDelete=False
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
}
