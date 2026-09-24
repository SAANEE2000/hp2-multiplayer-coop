// Server-authoritative non-combat Alohomora for Versus world interactions.
// The projectile keeps HP2's original dispatch contract: HPawn targets receive
// HandleSpellAlohomora, while spellTrigger handles the matching SpellType in
// its own Touch callback. No client opens movers or fires map events directly.
class HPVersusAlohomora extends HPVersusSpell;

function bool OnSpellHitHarry(Actor HitActor, Vector HitLocation)
{
    // Alohomora never damages or alters a Versus player.
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

    bAccepted = WorldTarget.HandleSpellAlohomora(self, HitLocation);
    Log("HPVersusWorldSpell spell=Alohomora target=" $ string(WorldTarget)
        $ " accepted=" $ string(bAccepted));
    return bAccepted;
}

defaultproperties
{
    SpellType=SPELL_Alohomora
    SeekSpeed=0.0
    fxFlyParticleEffectClass=Class'HPParticle.Aloh_Fly'
    fxHitParticleEffectClass=Class'HPParticle.Aloh_hit'
    ImpactSound=Sound'HPSounds.Magic_sfx.ALO_hit'
    Speed=1200.0
    MaxSpeed=1500.0
    SpellLifeTime=3.0
    LifeSpan=3.0
}
