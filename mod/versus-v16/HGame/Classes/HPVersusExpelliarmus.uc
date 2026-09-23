// The v18 projectile path without its conflicting shield-only cast override.
class HPVersusExpelliarmus extends HPVersusSpell;

function bool OnSpellHitHarry(Actor HitActor, Vector HitLocation)
{
    local HPVersusHarry Victim;

    Victim = HPVersusHarry(HitActor);
    if (Victim == None)
        return False;

    return Victim.HandleSpellDuelExpelliarmus(self, HitLocation);
}

defaultproperties
{
    SpellType=SPELL_DuelExpelliarmus
    SeekSpeed=0.0
    fxFlyParticleEffectClass=Class'HPParticle.duelExpelliarmus_fly'
    fxHitParticleEffectClass=Class'HPParticle.duelExpelliarmus_hit'
    Speed=1100.0
    MaxSpeed=1400.0
    SpellLifeTime=3.0
    LifeSpan=3.0
}
