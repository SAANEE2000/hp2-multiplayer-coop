// Respawning, server-authoritative FFA speed pickup.
class HPVersusSpeedPickup extends HProp;

var() float SpeedMultiplier;
var() float BoostDuration;
var() float RespawnTime;
var() float RotateSpeed;
var() float BobSpeed;
var() float BobHeight;
var() sound PickupSound;
var vector BaseLocation;
var float BobPhase;
var bool bAvailable;

replication
{
    reliable if (Role == ROLE_Authority)
        bAvailable;
}

function PostBeginPlay()
{
    Super.PostBeginPlay();
    BaseLocation = Location;
    bAvailable = True;
    SetCollision(True, False, False);
    bCollideWorld = False;
}

simulated function Tick(float DeltaTime)
{
    local Rotator R;
    local Vector P;

    Super.Tick(DeltaTime);
    bHidden = !bAvailable;
    if (!bAvailable)
        return;

    R = Rotation;
    R.Yaw += int(RotateSpeed * DeltaTime);
    SetRotation(R);
    BobPhase += BobSpeed * DeltaTime;
    P = BaseLocation;
    P.Z += BobHeight * Sin(BobPhase);
    SetLocation(P);
}

function Touch(Actor Other)
{
    TryPickup(Other);
}

function Bump(Actor Other)
{
    TryPickup(Other);
}

function TryPickup(Actor Other)
{
    local HPVersusHarry H;
    local HPVersusGame G;

    if (Role != ROLE_Authority || !bAvailable)
        return;
    G = HPVersusGame(Level.Game);
    if (G == None || !G.bMatchInProgress)
        return;
    H = HPVersusHarry(Other);
    if (H == None || H.bVersusDead || H.IsVersusSpeedBoosted())
        return;

    H.ApplyVersusSpeedBoost(SpeedMultiplier, BoostDuration);
    bAvailable = False;
    bHidden = True;
    SetCollision(False, False, False);
    SetTimer(RespawnTime, False);
    if (PickupSound != None)
        PlaySound(PickupSound, SLOT_None, 1.5);
    Log("HPVersusSpeedPickup taken pawn=" $ string(H)
        $ " multiplier=" $ string(SpeedMultiplier)
        $ " duration=" $ string(BoostDuration));
}

function Timer()
{
    ResetVersusPickup();
}

function ResetVersusPickup()
{
    if (Role != ROLE_Authority)
        return;
    SetTimer(0.0, False);
    bAvailable = True;
    bHidden = False;
    SetLocation(BaseLocation);
    SetCollision(True, False, False);
    Log("HPVersusSpeedPickup available location=" $ string(Location));
}

defaultproperties
{
    DrawType=DT_Mesh
    Mesh=SkeletalMesh'HPModels.skJarBeansMesh'
    DrawScale=1.0
    CollisionRadius=24.0
    CollisionHeight=20.0
    bCollideActors=True
    bCollideWorld=False
    bBlockActors=False
    bBlockPlayers=False
    bProjTarget=False
    bStatic=False
    bNoDelete=False
    bHidden=False
    Physics=PHYS_None
    AmbientGlow=64
    ScaleGlow=1.5
    bUnlit=True
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
    bNetTemporary=False
    SpeedMultiplier=1.5
    BoostDuration=10.0
    RespawnTime=30.0
    RotateSpeed=40000.0
    BobSpeed=2.0
    BobHeight=6.0
    PickupSound=Sound'HPSounds.pickup_wig_bark'
}
