// Original Harry states with native networking and an owning-client context.
// Mounting/MountFinish remain original pending explicit root-motion validation.
class HPCoopHarry extends harry;

var travel byte CoopSlot;
var BaseCam LocalCoopCamera;
var bool bLocalContextReady;
var config bool bCoopDebug;
var bool bCoopLoginNotified;
var bool bCoopReadySent;
var float NextCoopCastTime;
var float LastCoopRejectLogTime;
var float CoopCastInterval;
var bool bCoopStoryCaptured;
var bool bLocalCaptureApplied;
var HPCoopCutsceneView CoopStoryView;
var float PreCutFOV;
var int LastPresentedScene;

replication
{
    reliable if (Role == ROLE_Authority)
        CoopSlot, ClientCoopReady, bCoopStoryCaptured, ClientCoopCapture, ClientCoopSubtitle;
    reliable if (Role < ROLE_Authority)
        ServerCoopReady, ServerCastCoopSpell;
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
    EnsureCoopWand();
    if (Role == ROLE_Authority && Level.NetMode == NM_DedicatedServer && myHUD == None)
        myHUD = Spawn(Class'HPCoopServerHUD', self);
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
    if (Role == ROLE_Authority && (IsInState('InvalidState') || IsInState('CoopJoining')))
        GotoState('PlayerWalking');
    Log("[MP_LOGIN] possess pawn=" $ self $ " slot=" $ CoopSlot $ " local=" $ IsLocalCoopPlayer()
        $ " state=" $ GetStateName() $ " weapon=" $ Weapon);
}

event TravelPostAccept()
{
    Super(PlayerPawn).TravelPostAccept();
    EnsureCoopWand();
    EnsureLocalCoopContext();
}

function ClientCoopReady(byte Slot)
{
    CoopSlot = Slot;
    bCoopLoginNotified = True;
    Log("[MP_LOGIN] ready-notice pawn=" $ self $ " local=" $ IsLocalCoopPlayer()
        $ " state=" $ GetStateName() $ " weapon=" $ Weapon);
    EnsureLocalCoopContext();
}

function ServerCoopReady()
{
    local HPCoopGame G;
    G = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || G == None || !G.IsAliveCoopPlayer(self)) return;
    if (IsInState('InvalidState') || IsInState('CoopJoining'))
        GotoState('PlayerWalking');
    G.PlayerContextReady(self);
}

function EnsureCoopWand()
{
    local HPCoopWand W;
    W = HPCoopWand(Weapon);
    if (W != None)
    {
        W.BindCoopOwner();
        return;
    }
    if (Role != ROLE_Authority || Level.NetMode == NM_Client) return;
    W = HPCoopWand(FindInventoryType(Class'HPCoopWand'));
    if (W == None)
    {
        W = Spawn(Class'HPCoopWand', self,, Location);
        if (W == None) return;
        W.Instigator = self;
        W.BecomeItem();
        AddInventory(W);
        W.GiveAmmo(self);
    }
    PendingWeapon = W;
    ChangedWeapon();
    W.BindCoopOwner();
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
    if (myHUD == None)
        myHUD = Spawn(Class'HPHud', self);
    EnsureCoopStatus();
    EnsureCoopAnimation();
    EnsureCoopWand();
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
    if (HPConsole(Player.Console) != None)
        menuBook = HPConsole(Player.Console).menuBook;
    if (bCoopLoginNotified && bLocalContextReady && HPCoopWand(Weapon) != None
        && (IsInState('InvalidState') || IsInState('CoopJoining')))
        GotoState('PlayerWalking');
    if (bCoopLoginNotified && !bCoopReadySent && Cam != None
        && myHUD != None && SpellCursor != None && HPCoopWand(Weapon) != None)
    {
        bCoopReadySent = True;
        ServerCoopReady();
        Log("[MP_LOGIN] local-context-ready pawn=" $ self $ " slot=" $ CoopSlot);
    }
    ApplyCoopCapturePresentation();
}

function ClearCoopPrediction()
{
    local SavedMove Move;
    while (SavedMoves != None)
    {
        Move = SavedMoves;
        SavedMoves = Move.NextMove;
        Move.Clear();
        Move.NextMove = FreeMoves;
        FreeMoves = Move;
    }
    if (PendingMove != None)
    {
        PendingMove.Clear();
        PendingMove.NextMove = FreeMoves;
        FreeMoves = PendingMove;
        PendingMove = None;
    }
    bUpdatePosition = False;
}

function ClientCoopCapture(bool bCapture, HPCoopCutsceneView NewView,
    vector AuthorityLocation, rotator AuthorityRotation)
{
    bCoopStoryCaptured = bCapture;
    CoopStoryView = NewView;
    if (!IsLocalCoopPlayer()) return;
    ClearCoopPrediction();
    if (!bCapture)
    {
        SetLocation(AuthorityLocation);
        SetRotation(AuthorityRotation);
        ViewRotation = AuthorityRotation;
        Velocity = vect(0,0,0);
        Acceleration = vect(0,0,0);
    }
    ApplyCoopCapturePresentation();
}

function ApplyCoopCapturePresentation()
{
    if (!IsLocalCoopPlayer() || myHUD == None
        || bLocalCaptureApplied == bCoopStoryCaptured) return;
    bLocalCaptureApplied = bCoopStoryCaptured;
    bIsCaptured = bCoopStoryCaptured;
    bKeepStationary = bCoopStoryCaptured;
    bPressedJump = False;
    bAltFire = 0;
    bFire = 0;
    ClearCoopPrediction();
    if (bCoopStoryCaptured)
    {
        PreCutFOV = FOVAngle;
        if (SpellCursor != None && HPCoopWand(Weapon) != None)
            TurnOffSpellCursor();
        myHUD.StartCutScene();
    }
    else
    {
        myHUD.ClearSubtitleText();
        myHUD.EndCutScene();
        FOVAngle = PreCutFOV;
        Cam = LocalCoopCamera;
        ViewTarget = LocalCoopCamera;
        if (Cam != None)
        {
            Cam.PlayerHarry = self;
            Cam.InitTarget(self);
            Cam.InitPositionAndRotation(True);
        }
    }
    Log("[MP_CUTSCENE] local-capture=" $ bCoopStoryCaptured $ " pawn=" $ self
        $ " camera=" $ Cam $ " view=" $ ViewTarget);
}

function ClientCoopSubtitle(string Text, float Duration)
{
    if (!IsLocalCoopPlayer() || myHUD == None) return;
    if (Text == "") myHUD.ClearSubtitleText();
    else myHUD.SetSubtitleText(Text, Duration);
}

event PlayerCalcView(out Actor ViewActor, out vector CameraLocation, out rotator CameraRotation)
{
    if (bCoopStoryCaptured && CoopStoryView != None && CoopStoryView.HasCoopView())
    {
        ViewActor = LocalCoopCamera;
        CameraLocation = CoopStoryView.CameraPosition;
        CameraRotation = CoopStoryView.CameraRotation;
        FOVAngle = CoopStoryView.CameraFOV;
        if (LastPresentedScene != CoopStoryView.SceneSerial)
        {
            LastPresentedScene = CoopStoryView.SceneSerial;
            Log("[MP_CAMERA] shared-view pawn=" $ self $ " scene=" $ LastPresentedScene
                $ " snapshot=" $ CoopStoryView.SnapshotSerial);
        }
        return;
    }
    Super.PlayerCalcView(ViewActor, CameraLocation, CameraRotation);
}

function ServerMove(float TimeStamp, vector InAccel, vector ClientLoc,
    bool NewbRun, bool NewbDuck, bool NewbJumpStatus, bool bFired,
    bool bAltFired, bool bForceFire, bool bForceAltFire, eDodgeDir DodgeMove,
    byte ClientRoll, int View, optional byte OldTimeDelta, optional int OldAccel)
{
    // Protect both the new move and the redundant old move before native
    // MoveAutonomous is reached. Scripted CutCommand movement is independent.
    if (Role == ROLE_Authority && bCoopStoryCaptured)
    {
        CurrentTimeStamp = FMax(CurrentTimeStamp, TimeStamp);
        return;
    }
    // Harry's AltFire is owner-side aiming/animation, not the gameplay cast.
    // Only the validated ServerCastCoopSpell RPC creates a world projectile.
    Super.ServerMove(TimeStamp, InAccel, ClientLoc, NewbRun, NewbDuck,
        NewbJumpStatus, False, False, False, False,
        DodgeMove, ClientRoll, View, OldTimeDelta, OldAccel);
}

exec function AltFire(optional float F)
{
    if (!IsLocalCoopPlayer() || bCoopStoryCaptured || Level.Pauser != "") return;
    Super.AltFire(F);
}

function makeTarget()
{
    if (!IsLocalCoopPlayer() || bCoopStoryCaptured) return;
    Super.makeTarget();
}

function TurnOffSpellCursor()
{
    bIsAimingWithCharge = False;
    if (baseWand(Weapon) != None)
        baseWand(Weapon).StopChargingSpell();
    if (SpellCursor != None)
        SpellCursor.TurnTargetingOff();
    GroundSpeed = GroundRunSpeed;
}

// The original animation-channel notify calls Cast when the wand is released.
// Only the owning viewport chooses a target; gameplay is resolved by the server.
function Cast()
{
    if (!IsLocalCoopPlayer() || SpellCursor == None || HPCoopWand(Weapon) == None)
        return;
    if (SpellCursor.IsLockedOn() && !bInDuelingMode && !bHarryUsingSword)
        ServerCastCoopSpell(SpellCursor.aCurrentTarget, SpellCursor.vTargetOffset);
    TurnOffSpellCursor();
}

function RejectCoopCast(string Reason)
{
    if (bCoopDebug || Level.TimeSeconds - LastCoopRejectLogTime >= 1)
    {
        LastCoopRejectLogTime = Level.TimeSeconds;
        Log("[MP_SPELL] rejected pawn=" $ self $ " reason=" $ Reason);
    }
}

function ServerCastCoopSpell(Actor Target, vector TargetOffset)
{
    local HPCoopGame G;
    local HPCoopWand W;
    local Class<baseSpell> SpellClass;
    local vector Muzzle, AimPoint, AimDirection, HitLocation, HitNormal;
    local Actor Obstruction;
    local float MaxRange, RadiusBound, HeightBound;
    local rotator FlatRotation;

    if (Role != ROLE_Authority || Level.NetMode == NM_Client) return;
    G = HPCoopGame(Level.Game);
    W = HPCoopWand(Weapon);
    if (G == None || !G.IsCoopPlayer(self) || Player == None || bDeleteMe
        || G.bWaitingForPlayers || bIsCaptured || !bCanCast || HarryIsDead()
        || !IsInState('PlayerWalking') || CarryingActor != None
        || bInDuelingMode || bHarryUsingSword || W == None || W.Owner != self)
    {
        RejectCoopCast("player-state");
        return;
    }
    if (Level.TimeSeconds < NextCoopCastTime)
    {
        RejectCoopCast("cooldown");
        return;
    }
    if (Target == None || Target.bDeleteMe || Target.bHidden || Target == self
        || harry(Target) != None || Target.eVulnerableToSpell == SPELL_None
        || !Target.bProjTarget || !Target.bCollideActors
        || (Pawn(Target) == None && GridMover(Target) == None && spellTrigger(Target) == None))
    {
        RejectCoopCast("target");
        return;
    }
    SpellClass = W.GetClassFromSpellType(Target.eVulnerableToSpell);
    if (!W.IsSupportedCoopSpell(SpellClass) || !IsInSpellBook(Target.eVulnerableToSpell))
    {
        RejectCoopCast("spell-locked-or-unsupported");
        return;
    }
    // The request cannot place an impact point outside the target's bounds.
    RadiusBound = FMax(Target.CollisionRadius, 32) + 16;
    HeightBound = FMax(Target.CollisionHeight, 32) + 16;
    if (Abs(TargetOffset.X) > RadiusBound || Abs(TargetOffset.Y) > RadiusBound
        || Abs(TargetOffset.Z) > HeightBound)
    {
        RejectCoopCast("target-offset");
        return;
    }
    FlatRotation = Rotation;
    FlatRotation.Pitch = 0;
    FlatRotation.Roll = 0;
    Muzzle = Location + vector(FlatRotation) * (CollisionRadius + 8);
    Muzzle.Z += CollisionHeight * 0.5;
    AimPoint = Target.Location + TargetOffset;
    AimDirection = Normal(AimPoint - Muzzle);
    MaxRange = Class'SpellCursor'.Default.fLOS_Distance * 1.25;
    if (VSize(AimPoint - Muzzle) > MaxRange
        || (AimDirection Dot vector(ViewRotation)) < 0.2)
    {
        RejectCoopCast("range-or-facing");
        return;
    }
    if (spellTrigger(Target) != None
        && (!spellTrigger(Target).bInitiallyActive
            || (spellTrigger(Target).bHitJustFromFront
                && (AimDirection Dot vector(Target.Rotation)) >= 0)))
    {
        RejectCoopCast("trigger-inactive-or-backface");
        return;
    }
    Obstruction = Trace(HitLocation, HitNormal, AimPoint, Muzzle, True);
    if (Obstruction != None && Obstruction != Target)
    {
        RejectCoopCast("line-of-sight");
        return;
    }
    if (W.CastCoopSpell(self, SpellClass, Target, TargetOffset, Muzzle, rotator(AimDirection)) != None)
        NextCoopCastTime = Level.TimeSeconds + CoopCastInterval;
}

function bool UseEngineNetworkMovement()
{
    return True;
}

function bool UseNetworkMovementAnimation()
{
    // Keep original ProcessMove animation selection until a complete co-op
    // classifier replaces it; this is independent of native ReplicateMove.
    return False;
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

event PlayerInput(float DeltaTime)
{
    // Paused net pawns also receive PlayerInput on dedicated. Original Harry
    // reads HUD/Console here, which only exist in the owning viewport.
    if (!IsLocalCoopPlayer()) return;
    EnsureLocalCoopContext();
    if (bCoopStoryCaptured)
    {
        bPressedJump = False;
        bAltFire = 0;
        bFire = 0;
        aForward = 0;
        aStrafe = 0;
        aTurn = 0;
        aLookUp = 0;
        return;
    }
    if (myHUD != None)
        Super.PlayerInput(DeltaTime);
}

auto state CoopJoining
{
    event PlayerTick(float DeltaTime)
    {
        // Network actor creation may set the initial state after Possess.
        // Bootstrap once; readiness moves us into the original walking state.
        EnsureLocalCoopContext();
    }
}

simulated event Tick(float DeltaTime)
{
    // Do not inherit v18 harry.Tick's unconditional standard-camera override.
    // No movement, input unlock or forced state transition belongs here.
}

state PlayerWalking
{
    function StartAiming(bool bUsingSword)
    {
        if (!IsLocalCoopPlayer() || bCoopStoryCaptured || Level.Pauser != "") return;
        Super.StartAiming(bUsingSword);
    }

    event PlayerTick(float DeltaTime)
    {
        // The original state continues after Global.PlayerTick. Its remaining
        // body accesses camera/cursor, so guard this dispatch on dedicated too.
        if (!IsLocalCoopPlayer()) return;
        EnsureLocalCoopContext();
        if (Level.Pauser != "" || bCoopStoryCaptured)
        {
            bPressedJump = False;
            return;
        }
        Super.PlayerTick(DeltaTime);
    }

    function PlayerMove(float DeltaTime)
    {
        if (Level.Pauser != "" || bCoopStoryCaptured) return;
        Super.PlayerMove(DeltaTime);
    }

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
    CoopCastInterval=0.35
}
