// Server-authoritative Spongify activation projectile. It preserves the stock
// HandleSpellSpongify callback instead of translating the spell into an
// arbitrary vertical impulse.
class HPVersusSpongify extends HPVersusSpell;

function bool OnSpellHitHarry(Actor HitActor, Vector HitLocation)
{
    return False;
}

function bool OnSpellHitHPawn(Actor HitActor, Vector HitLocation)
{
    local HPawn WorldTarget;
    local bool bAccepted;

    if (Role != ROLE_Authority || HitActor == None
        || HitActor.IsA('harry'))
        return False;

    WorldTarget = HPawn(HitActor);
    if (WorldTarget == None)
        return False;

    bAccepted = WorldTarget.HandleSpellSpongify(self, HitLocation);
    Log("HPVersusWorldSpell spell=Spongify target=" $ string(WorldTarget)
        $ " accepted=" $ string(bAccepted));
    return bAccepted;
}

defaultproperties
{
    SpellType=SPELL_Spongify
    SeekSpeed=0.0
    fxFlyParticleEffectClass=Class'HPParticle.Spongify_Fly'
    fxHitParticleEffectClass=Class'HPParticle.Spongify_Hit'
    Speed=1200.0
    MaxSpeed=1500.0
    SpellLifeTime=3.0
    LifeSpan=3.0
}
