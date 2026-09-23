// Compact v18 donor adaptation on the proven v16 network projectile.
class HPVersusMimblewimble extends HPVersusSpell;

function bool OnSpellHitHarry(Actor HitActor, Vector HitLocation)
{
    local HPVersusHarry Victim;

    Victim = HPVersusHarry(HitActor);
    if (Victim == None)
        return False;

    return Victim.HandleSpellDuelMimblewimble(self, HitLocation);
}

defaultproperties
{
    SpellType=SPELL_DuelMimblewimble
    SeekSpeed=0.0
    fxFlyParticleEffectClass=Class'HPParticle.duelMimblewimble_fly'
    fxHitParticleEffectClass=Class'HPParticle.duelMimblewimble_hit'
    Speed=1200.0
    MaxSpeed=1500.0
    SpellLifeTime=3.0
    LifeSpan=3.0
}
