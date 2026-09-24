// Reproducible interaction fixture spawned only on HPV_Interactions.unr.
// The map itself is a byte-for-byte copy of the accepted startup arena.
class HPVersusInteractionArena extends Info;

var HPVersusArenaLock DoorLock;
var HPVersusArenaBarrier DoorBarrier;
var HPVersusArenaLock SecretLock;
var HPVersusArenaBarrier SecretBarrier;
var HPVersusArenaCauldron FlipendoObject;
var HPVersusArenaFlipendoTrigger FlipendoTrigger;
var HPVersusArenaBarrier MechanismBarrier;
var HPVersusSpongifyPad SpongifyPadActor;
var HPVersusSpongifyTarget SpongifyTargetActor;
var HPVersusHealthPickup RouteHealth;
var HPVersusSpeedPickup RouteSpeed;
var vector ArenaCenter;
var bool bArenaReady;
var bool bWorldProbeRunning;
var bool bWorldProbeComplete;
var byte WorldProbeStage;
var float WorldProbeNextTime;
var vector WorldProbeTarget;
var int WorldProbeStartHealth;

replication
{
    reliable if (Role == ROLE_Authority)
        bArenaReady;
}

function Vector Offset(float X, float Y, float Z)
{
    local vector V;
    V = ArenaCenter;
    V.X += X;
    V.Y += Y;
    V.Z += Z;
    return V;
}

function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Role == ROLE_Authority)
        BuildArena();
}

simulated event PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    if (Role < ROLE_Authority)
        Log("HPVersusWorldClient arena=" $ string(self)
            $ " ready=" $ string(bArenaReady));
}

function DestroyArenaActor(Actor A)
{
    if (A != None && !A.bDeleteMe)
        A.Destroy();
}

function ClearArena()
{
    DestroyArenaActor(DoorLock);
    DestroyArenaActor(DoorBarrier);
    DestroyArenaActor(SecretLock);
    DestroyArenaActor(SecretBarrier);
    DestroyArenaActor(FlipendoObject);
    DestroyArenaActor(FlipendoTrigger);
    DestroyArenaActor(MechanismBarrier);
    DestroyArenaActor(SpongifyPadActor);
    DestroyArenaActor(SpongifyTargetActor);
    DestroyArenaActor(RouteHealth);
    DestroyArenaActor(RouteSpeed);
    DoorLock = None;
    DoorBarrier = None;
    SecretLock = None;
    SecretBarrier = None;
    FlipendoObject = None;
    FlipendoTrigger = None;
    MechanismBarrier = None;
    SpongifyPadActor = None;
    SpongifyTargetActor = None;
    RouteHealth = None;
    RouteSpeed = None;
    bArenaReady = False;
}

function BuildArena()
{
    local HPVersusGame G;

    if (Role != ROLE_Authority)
        return;
    ClearArena();
    G = HPVersusGame(Level.Game);
    if (G == None)
        return;
    ArenaCenter = G.GetVersusPickupCenter();

    DoorBarrier = Spawn(Class'HPVersusArenaBarrier',,,
        Offset(330, 130, 0), rot(0,0,0));
    if (DoorBarrier != None)
        DoorBarrier.Tag = 'VersusAlohomoraDoor';
    DoorLock = Spawn(Class'HPVersusArenaLock',,,
        Offset(220, 130, 10), rot(0,0,0));
    if (DoorLock != None)
        DoorLock.Event = 'VersusAlohomoraDoor';
    RouteHealth = Spawn(Class'HPVersusHealthPickup',,,
        Offset(430, 130, 0), rot(0,0,0));

    SecretBarrier = Spawn(Class'HPVersusArenaBarrier',,,
        Offset(-330, -130, 0), rot(0,0,0));
    if (SecretBarrier != None)
        SecretBarrier.Tag = 'VersusAlohomoraSecret';
    SecretLock = Spawn(Class'HPVersusArenaLock',,,
        Offset(-220, -130, 10), rot(0,32768,0));
    if (SecretLock != None)
        SecretLock.Event = 'VersusAlohomoraSecret';
    RouteSpeed = Spawn(Class'HPVersusSpeedPickup',,,
        Offset(-430, -130, 0), rot(0,0,0));

    FlipendoObject = Spawn(Class'HPVersusArenaCauldron',,,
        Offset(180, -300, 0), rot(0,0,0));
    MechanismBarrier = Spawn(Class'HPVersusArenaBarrier',,,
        Offset(-180, 300, 0), rot(0,0,0));
    if (MechanismBarrier != None)
        MechanismBarrier.Tag = 'VersusFlipendoMechanism';
    FlipendoTrigger = Spawn(Class'HPVersusArenaFlipendoTrigger',,,
        Offset(-180, 235, 15), rot(0,0,0));
    if (FlipendoTrigger != None)
        FlipendoTrigger.Event = 'VersusFlipendoMechanism';

    SpongifyPadActor = Spawn(Class'HPVersusSpongifyPad',,,
        Offset(0, 0, -42), rot(0,0,0));
    SpongifyTargetActor = Spawn(Class'HPVersusSpongifyTarget',,,
        Offset(0, 240, -42), rot(0,0,0));
    if (SpongifyPadActor != None && SpongifyTargetActor != None)
    {
        SpongifyPadActor.Target = SpongifyTargetActor;
        SpongifyPadActor.fTimeToHitTarget = 2.0;
    }

    bArenaReady = DoorLock != None && DoorBarrier != None
        && SecretLock != None && SecretBarrier != None
        && FlipendoObject != None && FlipendoTrigger != None
        && MechanismBarrier != None && SpongifyPadActor != None
        && SpongifyTargetActor != None && RouteHealth != None
        && RouteSpeed != None;
    Log("HPVersusInteractionArena built ready=" $ string(bArenaReady)
        $ " center=" $ string(ArenaCenter)
        $ " doorLock=" $ string(DoorLock)
        $ " doorBarrier=" $ string(DoorBarrier)
        $ " secretLock=" $ string(SecretLock)
        $ " secretBarrier=" $ string(SecretBarrier)
        $ " flipObject=" $ string(FlipendoObject)
        $ " flipTrigger=" $ string(FlipendoTrigger)
        $ " mechanism=" $ string(MechanismBarrier)
        $ " pad=" $ string(SpongifyPadActor)
        $ " target=" $ string(SpongifyTargetActor)
        $ " health=" $ string(RouteHealth)
        $ " speed=" $ string(RouteSpeed));
}

function ResetArena()
{
    if (Role != ROLE_Authority)
        return;
    ClearArena();
    SetTimer(0.05, False);
}

function Timer()
{
    if (Role == ROLE_Authority && !bArenaReady)
        BuildArena();
}

function ProbeResult(bool bPassed, string CheckName)
{
    if (bPassed)
        Log("HPVersusWorldProbe PASS check=" $ CheckName);
    else
        Log("HPVersusWorldProbe FAIL check=" $ CheckName);
}

function RunWorldProbe(HPVersusHarry A, HPVersusHarry B)
{
    local HPVersusAlohomora Alohomora;
    local HPVersusFlipendo Flipendo;
    local HPVersusSpongify Spongify;
    local float EndpointDistance;
    local vector ProbeLocation;

    if (bWorldProbeComplete || !bArenaReady || A == None || B == None
        || Level.TimeSeconds < WorldProbeNextTime)
        return;

    if (!bWorldProbeRunning)
    {
        bWorldProbeRunning = True;
        Log("HPVersusWorldProbe START A=" $ string(A) $ " B=" $ string(B));
    }

    if (WorldProbeStage == 0)
    {
        Alohomora = Spawn(Class'HPVersusAlohomora', A,,
            DoorLock.Location, A.Rotation);
        if (Alohomora != None)
        {
            Alohomora.Instigator = A;
            Alohomora.OnSpellHitHPawn(DoorLock, DoorLock.Location);
            Alohomora.Destroy();
        }
        ProbeResult(Alohomora != None && DoorBarrier.bOpened
            && (DoorLock == None || DoorLock.bDeleteMe),
            "alohomora-stock-lock-event-opens-door");

        Flipendo = Spawn(Class'HPVersusFlipendo', A,,
            FlipendoObject.Location, A.Rotation);
        if (Flipendo != None)
        {
            Flipendo.Instigator = A;
            Flipendo.SpellCharge = 1.0;
            Flipendo.OnSpellHitHPawn(
                FlipendoObject, FlipendoObject.Location);
        }
        ProbeResult(Flipendo != None
            && FlipendoObject.GetStateName() == 'turnover',
            "flipendo-stock-object-state");
        if (Flipendo != None)
            FlipendoTrigger.Touch(Flipendo);
        ProbeResult(MechanismBarrier.bOpened && !FlipendoTrigger.bProjTarget,
            "flipendo-stock-spelltrigger-event");
        if (Flipendo != None)
            Flipendo.Destroy();

        ProbeLocation = SpongifyPadActor.Location;
        ProbeLocation.Z += 100.0;
        Spongify = Spawn(Class'HPVersusSpongify', A,,
            ProbeLocation, A.Rotation);
        if (Spongify != None)
        {
            Spongify.Instigator = A;
            Spongify.SpellCharge = 1.0;
            Spongify.OnSpellHitHPawn(
                SpongifyPadActor, SpongifyPadActor.Location);
            Spongify.Destroy();
        }
        WorldProbeTarget = SpongifyTargetActor.Location;
        WorldProbeStartHealth = A.Health;
        ProbeLocation = SpongifyPadActor.Location;
        ProbeLocation.Z += A.CollisionHeight
            + SpongifyPadActor.CollisionHeight + 1.0;
        A.SetLocation(ProbeLocation);
        SpongifyPadActor.OnBounce(A);
        ProbeResult(SpongifyPadActor.IsEnabled()
            && A.bVersusSpongifyActive && A.Physics == PHYS_Falling,
            "spongify-pad-active-owner-launched");
        WorldProbeStage = 1;
        WorldProbeNextTime = Level.TimeSeconds + 0.50;
        return;
    }

    if (A.Physics == PHYS_Falling)
    {
        WorldProbeNextTime = Level.TimeSeconds + 0.20;
        return;
    }

    EndpointDistance = VSize(
        (A.Location - WorldProbeTarget) * vect(1.0,1.0,0.0));
    ProbeResult(EndpointDistance < 110.0,
        "spongify-server-endpoint");
    ProbeResult(A.Health == WorldProbeStartHealth,
        "spongify-no-fall-damage");
    ProbeResult(A.Physics == PHYS_Walking && !A.bFrozen
        && !A.bVersusSpongifyActive,
        "spongify-next-native-movement-ready");
    bWorldProbeComplete = True;
    Log("HPVersusWorldProbe COMPLETE endpointDistance="
        $ string(EndpointDistance));
}

defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
    bNetNotify=True
}
