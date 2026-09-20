// Original Harry states with native networking and an owning-client context.
// Mounting/MountFinish remain original pending explicit root-motion validation.
class HPCoopHarry extends harry;

var travel byte CoopSlot;
var BaseCam LocalCoopCamera;
var bool bLocalContextReady;
var config bool bCoopDebug;

replication
{
    reliable if (Role == ROLE_Authority)
        CoopSlot, ClientCoopReady;
}

simulated function bool IsLocalCoopPlayer()
{
    return Player != None && Viewport(Player) != None;
}

event PreBeginPlay()
{
    // harry.PreBeginPlay accesses Player.Console before Login has a Player.
    Super(PlayerPawn).PreBeginPlay();
    FOVAngle = DesiredFOV;
    AddToSpellBook(Class'spellFlipendo');
    AddToSpellBook(Class'spellLumos');
    AddToSpellBook(Class'spellAlohomora');
    EnsureCoopStatus();
}

event PostBeginPlay()
{
    local int I;
    local name Sequence;
    Super(PlayerPawn).PostBeginPlay();
    HUDType = Class'HPHud';
    for (I = 1; I <= 16; I++)
    {
        Sequence = StringToAnimName("fidget_" $ I);
        if (Sequence == '') break;
        FidgetNums = I;
    }
    for (I = 1; I <= 16; I++)
    {
        Sequence = StringToAnimName("idle_" $ I);
        if (Sequence == '') break;
        IdleNums = I;
    }
    EnsureCoopAnimation();
    fTimeLastDrank = -1;
    SetTimer(1, True);
}

simulated event PostNetBeginPlay()
{
    Super(PlayerPawn).PostNetBeginPlay();
    if (Role == ROLE_SimulatedProxy)
    {
        bAlignBottom = True;
        bAlignBottomAlways = True;
        return;
    }
    EnsureLocalCoopContext();
}

event Possess()
{
    Super(PlayerPawn).Possess();
    EnsureLocalCoopContext();
    Log("[MP_LOGIN] possess pawn=" $ self $ " slot=" $ CoopSlot $ " local=" $ IsLocalCoopPlayer());
}

event TravelPostAccept()
{
    Super(PlayerPawn).TravelPostAccept();
    EnsureLocalCoopContext();
}

function ClientCoopReady(byte Slot)
{
    CoopSlot = Slot;
    EnsureLocalCoopContext();
}

function EnsureCoopStatus()
{
    local StatusGroup G;
    if (managerStatus == None)
    {
        managerStatus = Spawn(Class'StatusManager', self);
        if (managerStatus == None) return;
        managerStatus.PlayerHarry = self;
        managerStatus.CreateStartupItems();
        CopyAllStatusFromHarryToManager();
    }
    managerStatus.PlayerHarry = self;
    for (G = managerStatus.sgList; G != None; G = G.sgNext)
    {
        G.PlayerHarry = self;
        G.HUD = BaseHud(myHUD);
    }
}

function EnsureCoopAnimation()
{
    if (Role == ROLE_SimulatedProxy || HarryAnimChannel != None || Mesh == None)
        return;
    HarryAnimChannel = cHarryAnimChannel(CreateAnimChannel(Class'cHarryAnimChannel', AT_Replace, 'bip01 spine1'));
    if (HarryAnimChannel != None)
        HarryAnimChannel.SetOwner(self);
}

function EnsureLocalCoopContext()
{
    if (!IsLocalCoopPlayer()) return;
    // Compatibility pointer is local on clients, canonical on the server.
    if (Level.NetMode == NM_Client)
        Level.PlayerHarryActor = self;
    EnsureCoopStatus();
    EnsureCoopAnimation();
    if (LocalCoopCamera == None)
    {
        LocalCoopCamera = Spawn(Class'BaseCam', self);
        if (LocalCoopCamera == None) return;
        LocalCoopCamera.RemoteRole = ROLE_None;
        LocalCoopCamera.PlayerHarry = self;
        if (LocalCoopCamera.CamTarget != None)
        {
            LocalCoopCamera.CamTarget.RemoteRole = ROLE_None;
            LocalCoopCamera.CamTarget.PlayerHarry = self;
        }
        LocalCoopCamera.SetCameraMode(3);
        LocalCoopCamera.GotoState('StateStandardCam');
        LocalCoopCamera.InitTarget(self);
        LocalCoopCamera.InitPositionAndRotation(True);
    }
    Cam = LocalCoopCamera;
    Cam.PlayerHarry = self;
    if (!bLocalContextReady)
    {
        ViewTarget = Cam;
        bBehindView = False;
        bLocalContextReady = True;
        Log("[MP_CAMERA] bind pawn=" $ self $ " slot=" $ CoopSlot $ " cam=" $ Cam);
    }
    if (SpellCursor == None)
    {
        SpellCursor = Spawn(Class'SpellCursor', self);
        if (SpellCursor != None)
        {
            SpellCursor.RemoteRole = ROLE_None;
            SpellCursor.PlayerHarry = self;
            SpellCursor.TickParent = Cam;
            if (SpellCursor.SpellGesture != None)
                SpellCursor.SpellGesture.RemoteRole = ROLE_None;
        }
    }
    if (Player.Console != None)
        menuBook = HPConsole(Player.Console).menuBook;
}

function bool UseEngineNetworkMovement()
{
    return True;
}

function bool UseNetworkMovementAnimation()
{
    return True;
}

function OnHarryProcessMoveComplete()
{
    local rotator Body;
    if (!IsInState('PlayerWalking')) return;
    Body = Rotation;
    Body.Pitch = 0;
    Body.Roll = 0;
    SetRotation(Body);
}

function OnEngineNetworkCorrectionApplied()
{
    if (bCoopDebug)
        Log("[MP_MOVE] correction pawn=" $ self $ " state=" $ GetStateName() $ " loc=" $ Location);
}

function PlayerTick(float DeltaTime)
{
    if (IsLocalCoopPlayer())
    {
        EnsureLocalCoopContext();
        Super.PlayerTick(DeltaTime);
    }
}

simulated event Tick(float DeltaTime)
{
    // Do not inherit v18 harry.Tick's unconditional standard-camera override.
    // No movement, input unlock or forced state transition belongs here.
}

state PlayerWalking
{
    function BeginState()
    {
        Super.BeginState();
        // Parent selects the first map BaseCam; restore only this owner's camera.
        if (IsLocalCoopPlayer())
            EnsureLocalCoopContext();
    }
}

exec function CoopNetState()
{
    Log("[MP_MOVE] pawn=" $ self $ " slot=" $ CoopSlot $ " role=" $ Role
        $ " remoteRole=" $ RemoteRole $ " state=" $ GetStateName() $ " physics=" $ Physics
        $ " loc=" $ Location $ " vel=" $ Velocity $ " base=" $ Base
        $ " anim=" $ AnimSequence $ " frame=" $ AnimFrame);
    Log("[MP_CAMERA] pawn=" $ self $ " local=" $ IsLocalCoopPlayer()
        $ " cam=" $ Cam $ " view=" $ ViewTarget $ " context=" $ Level.PlayerHarryActor);
}

defaultproperties
{
    CoopSlot=255
    PlayerReplicationInfoClass=Class'HPCoopPRI'
    RemoteRole=ROLE_AutonomousProxy
    bAlwaysRelevant=True
    bCanStrafe=True
}
