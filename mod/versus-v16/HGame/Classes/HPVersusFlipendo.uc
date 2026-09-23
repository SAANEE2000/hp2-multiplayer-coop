// Server-authoritative v18 Flipendo idea, reduced to FFA damage and impulse.
class HPVersusFlipendo extends HPVersusSpell;

var float VersusPushStrength;
var float VersusPushUp;

function bool OnSpellHitHarry(Actor HitActor, Vector HitLocation)
{
    local HPVersusHarry Victim;
    local Pawn Attacker;
    local Vector PushDirection;
    local Vector Impulse;
    local int Damage;

    Victim = HPVersusHarry(HitActor);
    if (Victim == None || Victim.bVersusDead)
        return False;

    Attacker = Pawn(Owner);
    Damage = Victim.VersusDamage(2, int(8 * SpellCharge));
    Victim.TakeDamage(Damage, Attacker, HitLocation, vect(0,0,0), 'VersusFlipendo');
    if (Victim.bVersusDead)
        return True;

    PushDirection = Velocity;
    PushDirection.Z = 0;
    if (VSize(PushDirection) <= 1)
        PushDirection = Victim.Location - Location;
    PushDirection.Z = 0;
    PushDirection = Normal(PushDirection);

    Impulse = PushDirection * (VersusPushStrength * (0.5 + SpellCharge));
    Impulse.Z = VersusPushUp;
    Victim.ApplyVersusImpulse(Impulse);
    return True;
}

defaultproperties
{
    VersusPushStrength=600.0
    VersusPushUp=210.0
    SpellType=SPELL_Flipendo
    SeekSpeed=0.0
    fxFlyParticleEffectClass=Class'HPParticle.Flip_fly'
    fxHitParticleEffectClass=Class'HPParticle.Flip_hit'
    Speed=1200.0
    MaxSpeed=1500.0
    SpellLifeTime=3.0
    LifeSpan=3.0
}
