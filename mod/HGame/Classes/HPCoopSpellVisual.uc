// Presentation companion for an unreplicated, authoritative original spell.
// It has no collision, damage, target handler or trigger dispatch.
class HPCoopSpellVisual extends Actor;

var baseSpell SourceSpell;
var LumosLight SourceLumos;
var harry LumosCaster;
var bool bLumosVisual;
var bool bHadLocalLumosContext;
var float LumosScale;
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
        FlyEffectClass, bVisualReady, bFinished, bLumosVisual, LumosCaster;
    unreliable if (Role == ROLE_Authority)
        SpellPosition, SpellVelocity, SpellRotation, SnapshotSequence, LumosScale;
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

function InitCoopLumosVisual(LumosLight Light, harry Caster)
{
    if (Role != ROLE_Authority || Level.NetMode == NM_Client
        || Light == None || Caster == None)
        return;
    SourceLumos = Light;
    LumosCaster = Caster;
    bLumosVisual = True;
    FlyEffectClass = Class'LumosLightFX';
    SpellPosition = Light.Location;
    SpellVelocity = Caster.Velocity;
    SpellRotation = Caster.Rotation;
    LumosScale = 1;
    SnapshotSequence++;
    bFinished = False;
    bVisualReady = True;
    LifeSpan = 0;
}

function FinishCoopVisual()
{
    if (Role != ROLE_Authority || bFinished)
        return;
    bFinished = True;
    // A quick recast can revive this same actor before its final destruction.
    LifeSpan = 0.5;
}

simulated function UpdateCoopLumosOwnerContext()
{
    local HPCoopSpellVisual V;
    local LumosSparkles Sparkles;
    local bool bEnabled;

    if (!bLumosVisual || Level.NetMode == NM_DedicatedServer)
        return;
    if (LumosCaster == None || LumosCaster.Player == None
        || Viewport(LumosCaster.Player) == None)
    {
        if (!bHadLocalLumosContext)
            return;
        // Disconnect/respawn can clear the pawn reference before this visual
        // is destroyed. Preserve effects if a new local source already exists.
        foreach AllActors(Class'HPCoopSpellVisual', V)
        {
            if (!V.bDeleteMe && V.bLumosVisual && V.bVisualReady && !V.bFinished
                && V.LumosCaster != None && V.LumosCaster.Player != None
                && Viewport(V.LumosCaster.Player) != None)
                return;
        }
        foreach AllActors(Class'LumosSparkles', Sparkles)
        {
            Sparkles.TurnOffAreaEffects();
            Sparkles.TurnOffEdgeEffects();
        }
        bHadLocalLumosContext = False;
        return;
    }
    bHadLocalLumosContext = True;
    // The native renderer reads the actual viewport pawn's bLumosOn.
    // Never change the canonical global or another player's native flag.
    foreach AllActors(Class'HPCoopSpellVisual', V)
    {
        if (!V.bDeleteMe && V.bLumosVisual && V.bVisualReady && !V.bFinished
            && V.LumosCaster == LumosCaster)
        {
            bEnabled = True;
            break;
        }
    }
    LumosCaster.bLumosOn = bEnabled;
    foreach AllActors(Class'LumosSparkles', Sparkles)
        Sparkles.UpdateCoopLumosSparkles(LumosCaster, bEnabled);
}

simulated function StopLocalEffect()
{
    LightType = LT_None;
    LightBrightness = 0;
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
        if (bLumosVisual)
        {
            LocalFlyEffect.LifeSpan = 0;
            LocalFlyEffect.EnableEmission(True);
        }
        else
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
        if (bLumosVisual)
        {
            if (SourceLumos == None || SourceLumos.bDeleteMe
                || !SourceLumos.bLumosOn || LumosCaster == None)
                FinishCoopVisual();
            else
            {
                SpellPosition = SourceLumos.Location;
                SpellVelocity = LumosCaster.Velocity;
                SpellRotation = LumosCaster.Rotation;
                if (SourceLumos.bInfiniteLumos)
                    LumosScale = 0.75 - 0.5 * Abs(Sin(SourceLumos.fLumosTime * 0.25));
                else
                    LumosScale = FClamp(1 - SourceLumos.fLumosTime
                        / FMax(SourceLumos.fLumosTimeToTurnOff, 0.01), 0, 1);
                SnapshotSequence++;
            }
        }
        else if (SourceSpell == None || SourceSpell.bDeleteMe)
            FinishCoopVisual();
        else
        {
            SpellPosition = SourceSpell.Location;
            SpellVelocity = SourceSpell.Velocity;
            SpellRotation = SourceSpell.Rotation;
            SnapshotSequence++;
        }
    }
    if (bLumosVisual)
    {
        // Actor.LifeSpan is not replicated by this engine. The server owns
        // expiry; do not let the projectile visual's 12s client default win.
        if (Role < ROLE_Authority && !bFinished)
            LifeSpan = 0;
        UpdateCoopLumosOwnerContext();
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
    if (bLumosVisual)
    {
        // Original LumosLight scale and light parameters, applied locally.
        LocalFlyEffect.SizeWidth.Base = LocalFlyEffect.Default.SizeWidth.Base * LumosScale;
        LocalFlyEffect.SizeLength.Base = LocalFlyEffect.Default.SizeLength.Base * LumosScale;
        SetLocation(DrawPosition);
        LightType = LT_Steady;
        LightEffect = LE_NonIncidence;
        LightBrightness = 400;
        LightHue = 32;
        LightSaturation = 72;
        LightRadius = 5 + 10 * LumosScale;
        LightRadiusInner = 5;
    }
}

simulated event Destroyed()
{
    bFinished = True;
    UpdateCoopLumosOwnerContext();
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
