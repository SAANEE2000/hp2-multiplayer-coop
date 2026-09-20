// Presentation companion for an unreplicated, authoritative original spell.
// It has no collision, damage, target handler or trigger dispatch.
class HPCoopSpellVisual extends Actor;

var baseSpell SourceSpell;
var Class<ParticleFX> FlyEffectClass;
var vector SpellPosition;
var vector SpellVelocity;
var rotator SpellRotation;
var int SnapshotSequence;
var bool bVisualReady;
var bool bFinished;
var ParticleFX LocalFlyEffect;
var vector PreviousSnapshot;
var float SnapshotAge;
var float MaxExtrapolationTime;

replication
{
    reliable if (Role == ROLE_Authority)
        FlyEffectClass, bVisualReady, bFinished;
    unreliable if (Role == ROLE_Authority)
        SpellPosition, SpellVelocity, SpellRotation, SnapshotSequence;
}

function InitCoopSpellVisual(baseSpell S)
{
    if (Role != ROLE_Authority || S == None)
        return;
    SourceSpell = S;
    FlyEffectClass = S.fxFlyParticleEffectClass;
    SpellPosition = S.Location;
    SpellVelocity = S.Velocity;
    SpellRotation = S.Rotation;
    SnapshotSequence = 1;
    bVisualReady = True;
}

simulated function StopLocalEffect()
{
    if (LocalFlyEffect == None)
        return;
    LocalFlyEffect.Shutdown();
    LocalFlyEffect.Destroy();
    LocalFlyEffect = None;
}

simulated function EnsureLocalEffect()
{
    if (!bVisualReady || bFinished || FlyEffectClass == None
        || LocalFlyEffect != None || Level.NetMode == NM_DedicatedServer
        || (Role < ROLE_Authority && SnapshotSequence == 0))
        return;
    LocalFlyEffect = Spawn(FlyEffectClass, self,, SpellPosition, SpellRotation);
    if (LocalFlyEffect != None)
    {
        LocalFlyEffect.RemoteRole = ROLE_None;
        LocalFlyEffect.SetCollision(False, False, False);
        LocalFlyEffect.LifeSpan = Default.LifeSpan;
    }
}

simulated event Tick(float DeltaTime)
{
    local vector DrawPosition;

    if (Role == ROLE_Authority)
    {
        if (!bVisualReady)
            return;
        if (SourceSpell == None || SourceSpell.bDeleteMe)
        {
            if (!bFinished)
            {
                bFinished = True;
                // Allow the terminal state to replicate before destruction.
                LifeSpan = 0.5;
            }
        }
        else
        {
            SpellPosition = SourceSpell.Location;
            SpellVelocity = SourceSpell.Velocity;
            SpellRotation = SourceSpell.Rotation;
            SnapshotSequence++;
        }
    }
    if (bFinished)
    {
        StopLocalEffect();
        return;
    }
    if (!bVisualReady || Level.NetMode == NM_DedicatedServer)
        return;
    EnsureLocalEffect();
    if (LocalFlyEffect == None)
        return;

    DrawPosition = SpellPosition;
    if (Role < ROLE_Authority)
    {
        if (SpellPosition != PreviousSnapshot)
        {
            PreviousSnapshot = SpellPosition;
            SnapshotAge = 0;
        }
        else
            SnapshotAge += DeltaTime;
        DrawPosition += SpellVelocity * FMin(SnapshotAge, MaxExtrapolationTime);
    }
    LocalFlyEffect.SetLocation(DrawPosition);
    LocalFlyEffect.SetRotation(SpellRotation);
}

simulated event Destroyed()
{
    StopLocalEffect();
    Super.Destroyed();
}

defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
    bNetTemporary=False
    bHidden=True
    DrawType=DT_None
    Physics=PHYS_None
    bCollideActors=False
    bCollideWorld=False
    bBlockActors=False
    bBlockPlayers=False
    NetUpdateFrequency=30
    LifeSpan=12
    MaxExtrapolationTime=0.1
}
