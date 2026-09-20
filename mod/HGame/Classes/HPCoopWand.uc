// Original campaign projectiles with an authority-only co-op spawn boundary.
// The owning HPCoopHarry validates its RPC before calling CastCoopSpell.
// Lumos, sword, duel and forced boss casts are deliberately not supported yet.
class HPCoopWand extends baseWand;

var float CoopMuzzleMaxDistance;
var float CoopVisualTransformMaxDistance;

function PreBeginPlay()
{
    // Skip baseWand's unowned sword FX; campaign sword support is separate.
    Super(HWeapon).PreBeginPlay();
}

simulated function PostBeginPlay()
{
    // Original LumosLight.PreBeginPlay writes the global Harry's bLumosOn.
    // Do not spawn that actor until an owner-scoped Lumos path is integrated.
    Super(HWeapon).PostBeginPlay();
    BindCoopOwner();
}

simulated function BindCoopOwner()
{
    PlayerHarry = harry(Owner);
}

simulated function bool HasLocalCoopViewport()
{
    return PlayerHarry != None && PlayerHarry.Player != None
        && Viewport(PlayerHarry.Player) != None;
}

simulated function bool IsSupportedCoopSpell(Class<baseSpell> SpellClass)
{
    return SpellClass == Class'spellFlipendo'
        || SpellClass == Class'spellAlohomora'
        || SpellClass == Class'spellSkurge'
        || SpellClass == Class'spellRictusempra'
        || SpellClass == Class'spellDiffindo'
        || SpellClass == Class'spellSpongify';
}

simulated function Vector GetWandEndPoint()
{
    local Pawn P;
    local rotator FlatRot;
    local vector Point;

    P = Pawn(Owner);
    if (P == None)
        return Location;
    // This transform is presentation only. CastCoopSpell never reads it.
    if (P.WeaponLoc != vect(0,0,0)
        && VSize(P.WeaponLoc - P.Location) <= CoopVisualTransformMaxDistance)
        return P.WeaponLoc - (vect(0,0,20) >> P.WeaponRot);
    FlatRot = P.Rotation;
    FlatRot.Pitch = 0;
    FlatRot.Roll = 0;
    Point = P.Location + vector(FlatRot) * (P.CollisionRadius + 8);
    Point.Z += P.CollisionHeight * 0.5;
    return Point;
}

simulated function SetCurrentSpell(Class<baseSpell> SpellClass, optional bool bForceSelection)
{
    BindCoopOwner();
    if (SpellClass == None)
    {
        CurrentSpell = None;
        return;
    }
    if (PlayerHarry != None
        && (PlayerHarry.IsInSpellBook(SpellClass.Default.SpellType) || bForceSelection))
        CurrentSpell = SpellClass;
}

simulated function ChooseSpell(ESpellType NewSpellType, optional bool bForceSelection)
{
    local Class<baseSpell> SpellClass;

    switch (NewSpellType)
    {
        case SPELL_Flipendo: SpellClass = Class'spellFlipendo'; break;
        case SPELL_Alohomora: SpellClass = Class'spellAlohomora'; break;
        case SPELL_Lumos: SpellClass = Class'spellLumos'; break;
        case SPELL_Skurge: SpellClass = Class'spellSkurge'; break;
        case SPELL_Rictusempra: SpellClass = Class'spellRictusempra'; break;
        case SPELL_Diffindo: SpellClass = Class'spellDiffindo'; break;
        case SPELL_Spongify: SpellClass = Class'spellSpongify'; break;
    }
    // Lumos may be selected by the original cursor, but authority rejects it
    // explicitly until the owner-specific light and gargoyle path is ready.
    SetCurrentSpell(SpellClass, bForceSelection);
}

simulated function Texture GetSpellIcon()
{
    if (CurrentSpell != None)
        return CurrentSpell.Default.SpellIcon;
    return None;
}

simulated function DestroyCoopChargeEffect()
{
    if (fxChargeParticles == None)
        return;
    fxChargeParticles.Shutdown();
    fxChargeParticles.Destroy();
    fxChargeParticles = None;
}

simulated function StartChargingSpell(bool bChargeSpell,
    optional bool in_bHarryUsingSword, optional Class<baseSpell> ChargeSpellClass)
{
    local Class<ParticleFX> EffectClass;

    BindCoopOwner();
    DestroyCoopChargeEffect();
    bSpellCharges = bChargeSpell;
    fSpellCharge = 0;
    fSpellChargeTime = 0;
    fSwordFXTime = 0;
    if (in_bHarryUsingSword)
    {
        bSpellCharges = False;
        Log("[MP_SPELL] charge rejected reason=unsupported-sword owner=" $ Owner);
        return;
    }
    if (Level.NetMode == NM_DedicatedServer || !HasLocalCoopViewport())
        return;
    if (ChargeSpellClass == None)
        ChargeSpellClass = CurrentSpell;
    if (ChargeSpellClass != None)
        EffectClass = ChargeSpellClass.Default.fxFlyParticleEffectClass;
    if (EffectClass == None)
        EffectClass = Default.fxChargeParticleFXClass;
    fxChargeParticles = Spawn(EffectClass, self,, GetWandEndPoint());
    if (fxChargeParticles != None)
    {
        fxChargeParticles.RemoteRole = ROLE_None;
        fxChargeParticles.EnableEmission(True);
    }
}

simulated function StopChargingSpell()
{
    bSpellCharges = False;
    fSpellCharge = 0;
    fSpellChargeTime = 0;
    DestroyCoopChargeEffect();
}

simulated function float ChargingLevel()
{
    return fSpellCharge;
}

simulated function StartGlowingWand(Class<baseSpell> GlowSpellClass)
{
    // Safe local presentation; this does not enable duel spell gameplay.
    StartChargingSpell(False, False, GlowSpellClass);
    bGlowingWand = True;
}

simulated function StopGlowingWand()
{
    bGlowingWand = False;
    StopChargingSpell();
}

simulated function bool IsLumosOn()
{
    return False;
}

function LumosTurnOn()
{
    Log("[MP_SPELL] rejected reason=unsupported-lumos owner=" $ Owner);
}

function ToggleUseSword()
{
    Log("[MP_SPELL] rejected reason=unsupported-sword owner=" $ Owner);
}

simulated event Tick(float DeltaTime)
{
    BindCoopOwner();
    // Original baseWand.Tick dereferences Lumos/sword/charge FX on dedicated.
    if (Level.NetMode == NM_DedicatedServer || !HasLocalCoopViewport())
        return;
    if (PlayerHarry.Weapon != self)
    {
        DestroyCoopChargeEffect();
        return;
    }
    if (bSpellCharges)
    {
        fSpellChargeTime += DeltaTime;
        fSpellCharge = FClamp(fSpellChargeTime / FMax(fSpellChargeTimeSpan, 0.01), 0, 1);
    }
    if (fxChargeParticles != None)
        fxChargeParticles.SetLocation(GetWandEndPoint());
}

simulated event Destroyed()
{
    DestroyCoopChargeEffect();
    Super(HWeapon).Destroyed();
}

function CastSpell(optional Actor aTarget, optional Vector aTargetOffset,
    optional Class<baseSpell> SpellClass)
{
    // Never let an inherited local cast bypass the owning-pawn request.
    Log("[MP_SPELL] rejected reason=legacy-cast-path owner=" $ Owner);
}

function AltFire(float Value)
{
    Log("[MP_SPELL] rejected reason=legacy-altfire-path owner=" $ Owner);
}

function Projectile ProjectileFire2(Class<Projectile> ProjClass, float ProjSpeed,
    bool bWarn, optional bool bUseWeaponForProjRot, optional Actor aTarget)
{
    return None;
}

function baseSpell CastCoopSpell(harry Caster, Class<baseSpell> SpellClass,
    Actor Target, Vector TargetOffset, Vector ServerMuzzle, Rotator AimRot,
    optional float Charge)
{
    local baseSpell S;
    local HPCoopSpellVisual Visual;
    local vector TraceStart, HitLocation, HitNormal;
    local Actor Obstruction;

    if (Role != ROLE_Authority || Level.NetMode == NM_Client)
        return None;
    if (Caster == None || Owner != Caster || Caster.Weapon != self)
        return None;
    if (!IsSupportedCoopSpell(SpellClass))
    {
        Log("[MP_SPELL] rejected reason=unsupported-original-class class=" $ SpellClass);
        return None;
    }
    if (Target == None || Target.bDeleteMe || Target == Caster
        || !Caster.IsInSpellBook(SpellClass.Default.SpellType))
        return None;
    if (Target.eVulnerableToSpell != SpellClass.Default.SpellType)
        return None;
    if (VSize(ServerMuzzle - Caster.Location) > CoopMuzzleMaxDistance)
        return None;
    if (NumCastedSpells >= MAX_NUM_CASTED_SPELLS - 1)
        return None;

    // Recheck the final muzzle segment without camera or rendered bone data.
    TraceStart = Caster.Location;
    TraceStart.Z += Caster.CollisionHeight * 0.5;
    Obstruction = Caster.Trace(HitLocation, HitNormal, ServerMuzzle, TraceStart, True);
    if (Obstruction != None)
    {
        Log("[MP_SPELL] rejected reason=muzzle-obstructed actor=" $ Obstruction);
        return None;
    }

    BindCoopOwner();
    CurrentSpell = SpellClass;
    S = Spawn(SpellClass, Caster,, ServerMuzzle, AimRot);
    if (S == None)
        return None;
    // Original collision and seeking run only on the authoritative world.
    // The companion replicates presentation; no original client HitWall runs.
    S.RemoteRole = ROLE_None;
    S.Instigator = Caster;
    S.PlayerHarry = Caster;
    S.bUseDebugMode = bUseDebugMode;
    AddToCastedSpellList(S);
    S.InitSpell(Caster, Target, TargetOffset, FClamp(Charge, 0, 1), self);
    // Preserve original OnSpellInit, seeking, spell type and target handlers.
    // Do not replace randomized original direction after InitSpell.
    if (S.fxFlyParticleEffect != None)
    {
        S.fxFlyParticleEffect.RemoteRole = ROLE_None;
        S.fxFlyParticleEffect.SetOwner(S);
        S.fxFlyParticleEffect.EnableEmission(False);
        S.fxFlyParticleEffect.bHidden = True;
    }
    Visual = Spawn(Class'HPCoopSpellVisual', Caster,, S.Location, S.Rotation);
    if (Visual != None)
        Visual.InitCoopSpellVisual(S);
    else
        Log("[MP_SPELL] visual spawn failed spell=" $ S);
    S.PlayIncantationSound(Caster);
    Log("[MP_SPELL] original-spawn caster=" $ Caster $ " spell=" $ S
        $ " target=" $ Target $ " offset=" $ TargetOffset $ " muzzle=" $ ServerMuzzle);
    return S;
}

defaultproperties
{
    CoopMuzzleMaxDistance=128
    CoopVisualTransformMaxDistance=128
    bAutoSelectSpell=True
}
