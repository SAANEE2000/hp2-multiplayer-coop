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
var HPCoopCampaignState CoopCampaignState;
var bool bCoopProgressApplied;
var bool bCoopDead, bCoopPotionPending, bCoopAwaitResume, bCoopInDamage;
var bool bCoopDeathAnimFinished;
var int CoopStatusRevision, CoopHealth, CoopHealthPotential, CoopHealthLimit, CoopPotionCount;
var int CoopLifeSerial, LastCoopLifeSerial;
var float CoopRespawnAfter, NextCoopStatusTime, NextCoopPotionRequest;
var float CoopDeathAnimationEndedAt;
// Per-transition serials and explicit owner hold; no transient per-tick role swap.
var bool bCoopSceneMode, bCoopSceneEnterArmed, bCoopSceneAwaitRelease;
var bool bCoopSceneLocalHold, bCoopSceneLocalEnterPending;
var bool bCoopSceneLocalReleasePending, bCoopSceneLocalResumeSent, bCoopSceneSawSimulated;
var bool bCoopSavedClientAnim;
var ENetRole CoopSavedRemoteRole;
var int CoopSceneSerial, CoopLocalSceneSerial;
var float CoopSceneArmTime, CoopSceneResumeFloor, CoopSceneReleaseStamp;
var float CoopSceneOwnerHoldStamp, CoopSceneServerHoldTime;
var vector CoopSceneReleaseLocation;
var rotator CoopSceneReleaseRotation;
var EPhysics CoopSceneReleasePhysics;
var bool bCoopWalkIssued, bCoopWalkReached, bCoopWalkCueReceived, bCoopWalkBlocked;
var vector CoopWalkStart, CoopWalkGoal;
var Actor CoopWalkNotify;
var float CoopWalkNextSample;
var bool bCoopIntroInputHold, bCoopIntroLocalActive, bCoopIntroLocalFailed;
var bool bCoopIntroFailureCleaned, bCoopIntroRoleSent, bCoopIntroResumeCommitted;
var bool bCoopIntroOwnerTimeoutReported;
var bool bCoopIntroFailureDead, bCoopIntroFailureInstant, bCoopIntroFailureClub;
var int CoopIntroFailureLife, CoopIntroViewSerial, CoopIntroCameraCalls, CoopIntroLastSnapshot;
var float CoopIntroNextPulse, CoopIntroOwnerDeadline;
var string CoopIntroFailure;
var HPCoopIntroOwner CoopIntroOwner;
var HPCoopPickupObserver CoopPickupObserver;

replication
{
    reliable if (Role == ROLE_Authority)
        CoopSlot, ClientCoopReady, bCoopStoryCaptured, ClientCoopCapture, ClientCoopSubtitle,
        CoopCampaignState, ClientCoopStatus, ClientCoopLife,
        ClientCoopDrinkPotion, ClientCoopKnockBack,
        ClientCoopScenePrepare, ClientCoopSceneRelease, ClientCoopSceneCommitted,
        ClientCoopIntroCompleted, ClientCoopIntroFailed,
        ClientCoopPickupObserve, ClientCoopPickupCollected;
    reliable if (Role < ROLE_Authority)
        ServerCoopReady, ServerCastCoopSpell, ServerCoopDrinkPotion, ServerCoopResume,
        ServerCoopSceneCaptured, ServerCoopSceneResumed, ServerCoopPickupWitness,
        ServerCoopIntroSimulated;
}

simulated function bool IsLocalCoopPlayer()
{
    return Player != None && Viewport(Player) != None;
}

// Test witnesses only report object lifetime; no client report grants an item.
simulated function ClientCoopPickupObserve(int Serial, HProp Subject)
{
    if (Level.NetMode != NM_Client || !IsLocalCoopPlayer()
        || !(string(Level.Outer.Name) ~= "Ch1Rictusempra")
        || bCoopStoryCaptured || bCoopDead || bCoopSceneLocalHold || Subject == None)
        return;
    if (CoopPickupObserver == None)
        CoopPickupObserver = Spawn(Class'HPCoopPickupObserver', self);
    if (CoopPickupObserver != None) CoopPickupObserver.Observe(self, Serial, Subject);
}

simulated function ClientCoopPickupCollected(int Serial)
{
    if (Level.NetMode == NM_Client && IsLocalCoopPlayer() && CoopPickupObserver != None)
        CoopPickupObserver.Collected(Serial);
}

function ServerCoopPickupWitness(int Serial, byte Result, HProp Seen)
{
    local HPCoopGame G;
    local HPCoopPickupNetProbe Probe;
    G = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || G == None || !(G.RuntimeProbe ~= "PickupNet")
        || !G.IsAliveCoopPlayer(self) || Serial <= 0 || Result < 1 || Result > 4) return;
    foreach AllActors(Class'HPCoopPickupNetProbe', Probe, 'HPCoopPickupFixtureEvent')
        if (Probe.bArmed && !Probe.bFinished) Probe.ReportWitness(self, Serial, Result, Seen);
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
        $ " state=" $ GetStateName() $ " weapon=" $ Weapon $ " location=" $ Location);
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
    PublishCoopStatus(True);
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
    HarryAnimChannel = cHarryAnimChannel(CreateAnimChannel(Class'HPCoopHarryAnimChannel', AT_Replace, 'bip01 spine1'));
    if (HarryAnimChannel != None)
        HarryAnimChannel.SetOwner(self);
}

function EnsureLocalCoopContext()
{
    if (!IsLocalCoopPlayer()) return;
    if (!bCoopProgressApplied && CoopCampaignState != None)
    {
        bCoopProgressApplied = CoopCampaignState.ApplyTo(self);
        if (bCoopProgressApplied)
            Log("[MP_STORY_STATE] local-initial-state=" $ CurrentGameState
                $ " spells=" $ CoopCampaignState.LearnedSpellCount
                $ " test-stage=" $ CoopCampaignState.bIsTestStage);
    }
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
    if (bCoopLoginNotified && bCoopProgressApplied && !bCoopReadySent && Cam != None
        && myHUD != None && SpellCursor != None && HPCoopWand(Weapon) != None)
    {
        bCoopReadySent = True;
        ServerCoopReady();
        Log("[MP_LOGIN] local-context-ready pawn=" $ self $ " slot=" $ CoopSlot $ " location=" $ Location);
    }
    ApplyCoopCapturePresentation();
    ApplyCoopStatus();
}

simulated function ClearCoopPrediction()
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
    if (bCoopIntroLocalFailed) return;
    if (bCoopSceneLocalHold && !bCoopStoryCaptured) return;
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

simulated function ClientCoopSubtitle(string Text, float Duration)
{
    if (!IsLocalCoopPlayer() || myHUD == None) return;
    if (Text == "") myHUD.ClearSubtitleText();
    else myHUD.SetSubtitleText(Text, Duration);
}

simulated event PlayerCalcView(out Actor ViewActor, out vector CameraLocation, out rotator CameraRotation)
{
    // Source bCaptured can clear before the role update arrives. Retain the
    // last valid snapshot through the handoff; do not call non-sim Super at Role2.
    if (bCoopSceneLocalHold && CoopStoryView != None && CoopStoryView.SnapshotSerial > 0)
    {
        ViewActor = LocalCoopCamera;
        CameraLocation = CoopStoryView.CameraPosition;
        CameraRotation = CoopStoryView.CameraRotation;
        FOVAngle = CoopStoryView.CameraFOV;
        if (bCoopIntroLocalActive && CoopStoryView.SceneSerial == CoopIntroViewSerial)
        {
            CoopIntroCameraCalls++;
            CoopIntroLastSnapshot = CoopStoryView.SnapshotSerial;
        }
        return;
    }
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
    if (Role == ROLE_Authority && (bCoopStoryCaptured || bCoopDead || bCoopAwaitResume || bCoopSceneAwaitRelease || bCoopIntroInputHold))
    {
        CurrentTimeStamp = FMax(CurrentTimeStamp, TimeStamp);
        return;
    }
    if (Role == ROLE_Authority && TimeStamp <= CoopSceneResumeFloor) return;
    // Harry's AltFire is owner-side aiming/animation, not the gameplay cast.
    // Only the validated ServerCastCoopSpell RPC creates a world projectile.
    Super.ServerMove(TimeStamp, InAccel, ClientLoc, NewbRun, NewbDuck,
        NewbJumpStatus, False, False, False, False,
        DodgeMove, ClientRoll, View, OldTimeDelta, OldAccel);
}

function ClientAdjustPosition(float TimeStamp, name NewState, EPhysics NewPhysics,
    float NewLocX, float NewLocY, float NewLocZ,
    float NewVelX, float NewVelY, float NewVelZ, Actor NewBase)
{
    // A correction queued before death must not re-enter walking or replay
    // prediction. Only the reliable lifecycle message can revive this owner.
    if (bCoopDead || bCoopStoryCaptured || bCoopSceneLocalHold || NewState == 'CoopDead' || NewState == 'stateDead')
        return;
    Super.ClientAdjustPosition(TimeStamp, NewState, NewPhysics,
        NewLocX, NewLocY, NewLocZ, NewVelX, NewVelY, NewVelZ, NewBase);
}

exec function AltFire(optional float F)
{
    if (!IsLocalCoopPlayer() || bCoopStoryCaptured || bCoopSceneLocalHold || Level.Pauser != "") return;
    Super.AltFire(F);
}

function makeTarget()
{
    if (!IsLocalCoopPlayer() || bCoopStoryCaptured || bCoopSceneLocalHold) return;
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
    if (!IsLocalCoopPlayer() || bCoopStoryCaptured || bCoopSceneLocalHold
        || SpellCursor == None || HPCoopWand(Weapon) == None)
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
        || bCoopStoryCaptured || bCoopAwaitResume || bCoopSceneAwaitRelease || bCoopIntroInputHold
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

simulated function PlayerTick(float DeltaTime)
{
    if (CoopSceneOwnerTick()) return;
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
    if (bCoopStoryCaptured || bCoopDead || bCoopSceneLocalHold)
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
    // Native Role2 pawn branch dispatches Tick; normal owners use PlayerTick.
    // The separate owner actor also polls through dead/other pawn states.
    if (IsLocalCoopPlayer() && !bCoopIntroLocalFailed) CoopSceneOwnerTick();
}

function CoopAuthorityTick(float DeltaTime)
{
    if (Role == ROLE_Authority)
    {
        if (!IsLocalCoopPlayer()) fTimeSinceLastAcidHit += DeltaTime;
        if (Level.TimeSeconds >= NextCoopStatusTime)
        {
            NextCoopStatusTime = Level.TimeSeconds + 0.1;
            PublishCoopStatus();
        }
        CoopSceneAuthorityTick();
        CoopAuthorityMovementTick(DeltaTime);
    }
}

function CoopAuthorityMovementTick(float DeltaTime) {}

state PlayerWalking
{
    function CoopAuthorityMovementTick(float DeltaTime)
    {
        if (IsLocalCoopPlayer() || bCoopDead || bCoopStoryCaptured) return;
        if (GetHealthCount() <= 0)
        {
            KillHarry(True);
            return;
        }
        NoFallingDamageTimer = FMax(0, NoFallingDamageTimer - DeltaTime);
        // Original falling height/time bookkeeping without viewport input,
        // camera access or a second call to PlayerMove/AutonomousPhysics.
        ProcessFalling(DeltaTime);
    }

    event TakeDamage(int Damage, Pawn InstigatedBy, vector HitLocation,
        vector Momentum, name DamageType)
    {
        if (Role != ROLE_Authority || bCoopDead) return;
        // Keep the original authority Director callback before global damage.
        Super.TakeDamage(Damage, InstigatedBy, HitLocation, Momentum, DamageType);
    }

    function StartAiming(bool bUsingSword)
    {
        if (!IsLocalCoopPlayer() || bCoopStoryCaptured || bCoopSceneLocalHold || Level.Pauser != "") return;
        Super.StartAiming(bUsingSword);
    }

    simulated event PlayerTick(float DeltaTime)
    {
        if (CoopSceneOwnerTick()) return;
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
        if (Level.Pauser != "" || bCoopStoryCaptured || bCoopSceneLocalHold) return;
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


// Original StatusItemHealth remains the authority data model.
function TakeDamage(int Damage, Pawn InstigatedBy, vector HitLocation,
    vector Momentum, name DamageType)
{
    local HPCoopGame G;
    G = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || G == None || !G.IsCoopPlayer(self)
        || bCoopDead || Damage <= 0) return;
    EnsureCoopStatus();
    EnsureCoopAnimation();
    if (managerStatus == None || HarryAnimChannel == None) return;
    // The restored original retains difficulty, acid throttle, lethal damage
    // types, hurt audio, knockback, carried-object rules and automatic potion.
    bCoopInDamage = True;
    Super.TakeDamage(Damage, InstigatedBy, HitLocation, Momentum, DamageType);
    bCoopInDamage = False;
    PublishCoopStatus();
}

function SetHealth(int NewHealth)
{
    if (Role != ROLE_Authority) return;
    Super.SetHealth(NewHealth);
}

function AddHealth(int Amount)
{
    if (Role != ROLE_Authority || bCoopDead) return;
    Super.AddHealth(Amount);
}

function bool HarryIsDead()
{
    return bCoopDead || Super.HarryIsDead();
}

function PublishCoopStatus(optional bool bForce)
{
    local StatusItem HP, Potion;
    local int Current, Potential, Limit, Potions;
    if (Role != ROLE_Authority || Player == None || managerStatus == None) return;
    HP = GetHealthStatusItem();
    Potion = managerStatus.GetStatusItem(Class'StatusGroupPotions', Class'StatusItemWiggenwell');
    if (HP == None || Potion == None) return;
    Current = HP.nCount;
    Potential = HP.nCurrCountPotential;
    Limit = HP.nMaxCount;
    Potions = Potion.nCount;
    // Pawn.Health is only a compatibility mirror, never an alternative pool.
    Health = Current;
    if (!bForce && CoopStatusRevision != 0 && Current == CoopHealth
        && Potential == CoopHealthPotential && Limit == CoopHealthLimit
        && Potions == CoopPotionCount) return;
    CoopHealth = Current;
    CoopHealthPotential = Potential;
    CoopHealthLimit = Limit;
    CoopPotionCount = Potions;
    CoopStatusRevision++;
    ClientCoopStatus(CoopStatusRevision, Current, Potential, Limit, Potions);
    Log("[MP_HEALTH] pawn=" $ self $ " revision=" $ CoopStatusRevision
        $ " health=" $ Current $ "/" $ Potential $ " potions=" $ Potions);
}

function ClientCoopStatus(int Revision, int Current, int Potential, int Limit, int Potions)
{
    if (!IsLocalCoopPlayer() || Revision < CoopStatusRevision) return;
    if (Limit < 1 || Potential < 1 || Potential > Limit
        || Current < 0 || Current > Potential || Potions < 0) return;
    CoopStatusRevision = Revision;
    CoopHealth = Current;
    CoopHealthPotential = Potential;
    CoopHealthLimit = Limit;
    CoopPotionCount = Potions;
    ApplyCoopStatus();
    Log("[MP_HEALTH] local-status pawn=" $ self $ " revision=" $ Revision
        $ " health=" $ Current $ "/" $ Potential $ " potions=" $ Potions
        $ " applied-health=" $ GetHealthCount());
}

function ApplyCoopStatus()
{
    local StatusItem HP, Potion;
    local int Delta;
    if (!IsLocalCoopPlayer() || Role == ROLE_Authority
        || CoopStatusRevision == 0 || managerStatus == None) return;
    HP = GetHealthStatusItem();
    Potion = managerStatus.GetStatusItem(Class'StatusGroupPotions', Class'StatusItemWiggenwell');
    if (HP == None || Potion == None) return;
    HP.nMaxCount = CoopHealthLimit;
    HP.nCurrCountPotential = CoopHealthPotential;
    Delta = CoopHealth - HP.nCount;
    if (Delta != 0) HP.IncrementCount(Delta);
    Potion.SetCount(CoopPotionCount);
    Health = CoopHealth;
}

function DoDrinkWiggenwell()
{
    if (Role < ROLE_Authority)
    {
        if (IsLocalCoopPlayer() && !bCoopDead && !bCoopStoryCaptured && !bCoopSceneLocalHold
            && Level.TimeSeconds >= NextCoopPotionRequest)
        {
            NextCoopPotionRequest = Level.TimeSeconds + 0.25;
            ServerCoopDrinkPotion();
        }
        return;
    }
    ServerCoopDrinkPotion();
}

function ServerCoopDrinkPotion()
{
    local HPCoopGame G;
    local StatusItem Potion;
    G = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || G == None || !G.IsAliveCoopPlayer(self)
        || G.bWaitingForPlayers || bCoopDead || bCoopStoryCaptured
        || bCoopAwaitResume || bCoopSceneAwaitRelease || bCoopIntroInputHold
        || bCoopPotionPending || bInDuelingMode || bHarryUsingSword
        || (!bCoopInDamage && (!IsInState('PlayerWalking') || Physics != PHYS_Walking))) return;
    EnsureCoopAnimation();
    if (HarryAnimChannel == None || myHUD == None) return;
    Potion = managerStatus.GetStatusItem(Class'StatusGroupPotions', Class'StatusItemWiggenwell');
    if (Potion == None || Potion.nCount < 1
        || GetHealthCount() >= GetHealthStatusItem().nCurrCountPotential) return;
    bCoopPotionPending = True;
    Super.DoDrinkWiggenwell();
    if (!HarryAnimChannel.IsInState('stateDrinkWiggenwell'))
    {
        bCoopPotionPending = False;
        return;
    }
    // No client-provided health/count or completion time is accepted.
    ClientCoopDrinkPotion();
}

function ClientCoopDrinkPotion()
{
    if (!IsLocalCoopPlayer() || Role == ROLE_Authority || bCoopDead) return;
    EnsureCoopAnimation();
    StopAiming();
    DropCarryingActor(False);
    if (HarryAnimChannel != None) HarryAnimChannel.DoDrinkWiggenwell();
}

function CompleteCoopPotion()
{
    local StatusItem Potion;
    if (Role != ROLE_Authority || !bCoopPotionPending) return;
    bCoopPotionPending = False;
    if (bCoopDead || managerStatus == None) return;
    Potion = managerStatus.GetStatusItem(Class'StatusGroupPotions', Class'StatusItemWiggenwell');
    if (Potion == None || Potion.nCount < 1) return;
    Potion.IncrementCount(-1);
    AddHealth(100);
    PlaySound(Sound'health_boost1', SLOT_None);
    PublishCoopStatus();
}

function CoopNotifyKnockBack()
{
    if (Role == ROLE_Authority && !bCoopDead) ClientCoopKnockBack();
}

function ClientCoopKnockBack()
{
    if (!IsLocalCoopPlayer() || Role == ROLE_Authority || bCoopDead) return;
    EnsureCoopAnimation();
    if (HarryAnimChannel != None) HarryAnimChannel.DoKnockBack();
}

function KillHarry(bool bImmediateDeath)
{
    local HPCoopGame G;
    G = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || G == None || !G.IsCoopPlayer(self) || bCoopDead) return;
    bCoopDead = True;
    bCoopDeathAnimFinished = False;
    CoopDeathAnimationEndedAt = -1;
    bHarryKilled = True;
    bCoopPotionPending = False;
    bCoopAwaitResume = False;
    SetHealth(0);
    TurnOffSpellCursor();
    if (HPCoopWand(Weapon) != None) HPCoopWand(Weapon).DeactivateCoopLumos();
    if (HarryAnimChannel != None) HarryAnimChannel.GotoState('stateIdle');
    CoopLifeSerial++;
    CoopRespawnAfter = Level.TimeSeconds + 4.0;
    GotoState('CoopDead');
    PublishCoopStatus(True);
    ClientCoopLife(CoopLifeSerial, True, Location, Rotation, bInstantDeath, bClubDeath, CurrentTimeStamp);
    Log("[MP_DEATH] pawn=" $ self $ " serial=" $ CoopLifeSerial
        $ " instant=" $ bInstantDeath $ " club=" $ bClubDeath);
    G.CoopPlayerDied(self);
}

function KillHarryWithClub(bool bImmediateDeath, Actor A)
{
    local rotator Facing;
    if (Role != ROLE_Authority || A == None) return;
    // Original final facing, prepared before the owner death RPC is sent.
    bClubDeath = True;
    Facing = Rotation;
    Facing.Yaw = A.Rotation.Yaw + 16384;
    SetRotation(Facing);
    DesiredRotation = Facing;
    KillHarry(bImmediateDeath);
}

function ClientCoopLife(int Serial, bool bDead, vector Position, rotator Facing,
    bool bInstant, bool bClub, float AuthorityTimeStamp)
{
    if (!IsLocalCoopPlayer() || Serial <= LastCoopLifeSerial) return;
    LastCoopLifeSerial = Serial;
    if (Role == ROLE_Authority) return;
    bCoopDead = bDead;
    bHarryKilled = bDead;
    bInstantDeath = bInstant;
    bClubDeath = bClub;
    ClearCoopPrediction();
    CurrentTimeStamp = FMax(CurrentTimeStamp, AuthorityTimeStamp);
    Velocity = vect(0,0,0);
    Acceleration = vect(0,0,0);
    bPressedJump = False;
    bFire = 0;
    bAltFire = 0;
    if (bDead)
    {
        // Close the local upper-body operation before faint starts. In
        // particular, a potion EndState must not later replace faint with idle.
        bCoopPotionPending = False;
        if (HarryAnimChannel != None) HarryAnimChannel.GotoState('stateIdle');
        TurnOffSpellCursor();
        SetRotation(Facing);
        ViewRotation = Facing;
        GotoState('CoopDead');
        if (!SetLocation(Position))
            Log("[MP_DEATH] owner-position-refused pawn=" $ self $ " serial=" $ Serial);
    }
    else
    {
        SetLocation(Position);
        SetRotation(Facing);
        ViewRotation = Facing;
        bHidden = False;
        SetCollision(True, True, True);
        bCollideWorld = True;
        ResetCoopDeathFlags();
        GotoState('PlayerWalking');
        SetPhysics(PHYS_Walking);
        if (LocalCoopCamera != None) LocalCoopCamera.InitPositionAndRotation(True);
        ServerCoopResume(Serial);
    }
    Log("[MP_DEATH] local-life pawn=" $ self $ " serial=" $ Serial
        $ " dead=" $ bDead $ " state=" $ GetStateName() $ " location=" $ Location);
}

function ServerCoopResume(int Serial)
{
    if (Role == ROLE_Authority && !bCoopDead && bCoopAwaitResume && Serial == CoopLifeSerial)
    {
        bCoopAwaitResume = False;
        Log("[MP_RESPAWN] owner-resumed pawn=" $ self $ " serial=" $ Serial);
    }
}

function ResetCoopDeathFlags()
{
    bInstantDeath = False;
    bClubDeath = False;
    bSlowDeath = False;
    bHarryKilled = False;
    bThrow = False;
    bEctoFlashed = False;
    bPlayedEctoKnockBack = False;
    iEctoRefCount = 0;
    iWebAnimRefCount = 0;
    iEctoHurtSoundCount = 0;
    fTimeSinceLastAcidHit = 0.333;
    RotationRate = Default.RotationRate;
    AccelRate = Default.AccelRate;
    GroundSpeed = GroundRunSpeed;
}

function FinishCoopRevive(rotator Facing)
{
    if (Role != ROLE_Authority || !bCoopDead) return;
    bCoopDead = False;
    ResetCoopDeathFlags();
    // Original death recovery minimum, bounded by this player's own capacity.
    SetHealth(Min(iMinHealthAfterDeath, GetHealthStatusItem().nCurrCountPotential));
    Velocity = vect(0,0,0);
    Acceleration = vect(0,0,0);
    bHidden = False;
    SetRotation(Facing);
    ViewRotation = Facing;
    GotoState('PlayerWalking');
    SetPhysics(PHYS_Walking);
    SetCollision(True, True, True);
    CoopLifeSerial++;
    bCoopAwaitResume = !IsLocalCoopPlayer();
    PublishCoopStatus(True);
    ClientCoopLife(CoopLifeSerial, False, Location, Rotation, False, False, CurrentTimeStamp);
}

// This prevents native queued save on the co-op pawn. The separate original
// SavePoint touch adapter is still required before checkpoint books are ready.
function SaveGame()
{
    bQueuedToSaveGame = False;
    Log("[MP_CHECKPOINT] blocked reason=native-save-contract-unverified pawn=" $ self);
}

function bool CutCommand(string Command, optional string Cue, optional bool bFastFlag)
{
    local HPCoopGame G;
    G = HPCoopGame(Level.Game);
    if (G != None && G.IntroCoordinator != None && G.IntroCoordinator.IsMember(self))
    {
        if (G.IntroCoordinator.Phase == 6) return False;
        if (G.IntroCoordinator.IsActive() && self == G.StoryLeader
            && (ParseDelimitedString(Command, " ", 1, False) ~= "Release")
            && !G.IntroCoordinator.CanRelease())
        {
            G.IntroCoordinator.Fail("release-before-verified-walk");
            return False;
        }
    }
    return Super.CutCommand(Command, Cue, bFastFlag);
}

function ServerCoopIntroSimulated(int Serial)
{
    local HPCoopGame G;
    G = HPCoopGame(Level.Game);
    if (Role == ROLE_Authority && G != None && G.IntroCoordinator != None)
        G.IntroCoordinator.SimulatedOwner(self, Serial);
}

function AbortCoopIntro(string Reason)
{
    if (Role != ROLE_Authority) return;
    bCoopIntroInputHold = True;
    if (bCoopSceneMode)
    {
        RemoteRole = CoopSavedRemoteRole;
        bClientAnim = bCoopSavedClientAnim;
    }
    CoopSceneSerial++;
    bCoopSceneMode = False;
    bCoopSceneEnterArmed = False;
    bCoopSceneAwaitRelease = False;
    Velocity = vect(0,0,0);
    Acceleration = vect(0,0,0);
    // Preserve the real dead/alive state. No Release command, cue, or walking state.
    ClientCoopIntroFailed(CoopSceneSerial, Reason, bCoopDead, CoopLifeSerial,
        bInstantDeath, bClubDeath, Location, Rotation, CurrentTimeStamp);
}

simulated function ClientCoopIntroFailed(int Serial, string Reason, bool bDead,
    int LifeSerial, bool bInstant, bool bClub, vector Position, rotator Facing,
    float AuthorityTimeStamp)
{
    if (!IsLocalCoopPlayer() || Serial < CoopLocalSceneSerial) return;
    CoopLocalSceneSerial = Serial;
    bCoopIntroLocalActive = True;
    bCoopIntroLocalFailed = True;
    bCoopIntroFailureCleaned = False;
    bCoopIntroOwnerTimeoutReported = False;
    CoopIntroOwnerDeadline = Level.TimeSeconds + 20;
    bCoopSceneLocalHold = True;
    bCoopSceneLocalEnterPending = False;
    bCoopSceneLocalReleasePending = False;
    bCoopSceneLocalResumeSent = False;
    CoopIntroFailure = Reason;
    bCoopIntroFailureDead = bDead;
    CoopIntroFailureLife = LifeSerial;
    bCoopIntroFailureInstant = bInstant;
    bCoopIntroFailureClub = bClub;
    CoopSceneReleaseLocation = Position;
    CoopSceneReleaseRotation = Facing;
    CoopSceneReleaseStamp = AuthorityTimeStamp;
    // Existing owner actor polls even when the pawn becomes CoopDead. If this
    // failed before prepare, the normal Role3 RPC can construct that actor now.
    EnsureCoopIntroOwner();
    PollCoopIntroOwner();
}

simulated function EnsureCoopIntroOwner()
{
    if (!IsLocalCoopPlayer() || CoopIntroOwner != None) return;
    CoopIntroOwner = Spawn(Class'HPCoopIntroOwner', self);
    if (CoopIntroOwner != None) CoopIntroOwner.LocalHarry = self;
}

simulated function PollCoopIntroOwner()
{
    if (!IsLocalCoopPlayer() || !bCoopIntroLocalActive) return;
    if (Level.TimeSeconds > CoopIntroOwnerDeadline && !bCoopIntroOwnerTimeoutReported)
    {
        bCoopIntroOwnerTimeoutReported = True;
        Log("[MP_INTRO] BLOCKED owner-watchdog; no forced role or input release");
        ClientCoopSubtitle("Co-op intro synchronization timed out. Leave and restart the host.", 300);
    }
    if (bCoopIntroLocalFailed)
    {
        if (Role != ROLE_AutonomousProxy || bCoopIntroFailureCleaned) return;
        bCoopIntroFailureCleaned = True;
        ClearCoopPrediction();
        Velocity = vect(0,0,0);
        Acceleration = vect(0,0,0);
        SetPhysics(PHYS_None);
        // A life RPC may have been absorbed while Role2. Re-deliver its exact
        // server death serial after Role3, without reviving or inventing health.
        if (bCoopIntroFailureDead)
            ClientCoopLife(CoopIntroFailureLife, True, CoopSceneReleaseLocation,
                CoopSceneReleaseRotation, bCoopIntroFailureInstant,
                bCoopIntroFailureClub, CoopSceneReleaseStamp);
        bCoopSceneLocalHold = False;
        bCoopStoryCaptured = False;
        bCoopIntroLocalFailed = False;
        ApplyCoopCapturePresentation();
        bCoopIntroLocalFailed = True;
        bCoopSceneLocalHold = True;
        CoopStoryView = None;
        ClientCoopSubtitle("Co-op intro stopped: " $ CoopIntroFailure
            $ ". Leave this session and restart the host.", 300);
        Log("[MP_INTRO] owner-failure-cleanup serial=" $ CoopLocalSceneSerial
            $ " role=" $ Role $ " dead=" $ bCoopDead);
        return;
    }
    if (Role == ROLE_SimulatedProxy && !bCoopIntroRoleSent)
    {
        bCoopIntroRoleSent = True;
        ServerCoopIntroSimulated(CoopLocalSceneSerial);
    }
    if (Level.TimeSeconds >= CoopIntroNextPulse)
    {
        CoopIntroNextPulse = Level.TimeSeconds + 1;
        Log("[MP_INTRO] owner-pulse serial=" $ CoopLocalSceneSerial
            $ " role=" $ Role $ " hold=" $ bCoopSceneLocalHold
            $ " camera-calls=" $ CoopIntroCameraCalls
            $ " snapshot=" $ CoopIntroLastSnapshot);
    }
}

simulated function ClientCoopIntroCompleted(int Serial)
{
    if (!IsLocalCoopPlayer() || !bCoopIntroLocalActive || bCoopIntroLocalFailed
        || !bCoopIntroResumeCommitted || Serial != CoopLocalSceneSerial
        || Role != ROLE_AutonomousProxy) return;
    ClearCoopPrediction();
    bCoopIntroLocalActive = False;
    bCoopSceneLocalHold = False;
    bCoopStoryCaptured = False;
    ApplyCoopCapturePresentation();
    Log("[MP_INTRO] owner-complete serial=" $ Serial $ " role=" $ Role);
}

// Diagnostic only: preserve the original native state/physics clock for one
// Ch1 intro capture. No helper calls MoveTo, AutonomousPhysics or ProcessState.
function BeginCoopAuthorityCapture(HPCoopCutsceneView SharedView)
{
    if (Role != ROLE_Authority || bCoopSceneMode || SharedView == None) return;
    bCoopSceneMode = True;
    bCoopSceneAwaitRelease = False;
    bCoopSceneEnterArmed = False;
    bCoopWalkIssued = False;
    bCoopWalkReached = False;
    bCoopWalkCueReceived = False;
    bCoopWalkBlocked = False;
    CoopSceneSerial++;
    CoopSavedRemoteRole = RemoteRole;
    bCoopSavedClientAnim = bClientAnim;
    ClientCoopCapture(True, SharedView, Location, Rotation);
    ClientCoopScenePrepare(CoopSceneSerial, SharedView, bCoopIntroInputHold,
        SharedView.SceneSerial);
    Log("[MP_CAPTURE_MODE] prepare serial=" $ CoopSceneSerial $ " pawn=" $ self
        $ " role=" $ Role $ " remote=" $ RemoteRole $ " location=" $ Location);
}

simulated function ClientCoopScenePrepare(int Serial, HPCoopCutsceneView SharedView,
    bool bIntroPreflight, int ViewSerial)
{
    if (!IsLocalCoopPlayer() || bCoopIntroLocalFailed || Serial <= CoopLocalSceneSerial) return;
    CoopLocalSceneSerial = Serial;
    bCoopIntroLocalActive = bIntroPreflight;
    if (bIntroPreflight)
    {
        CoopIntroViewSerial = ViewSerial;
        CoopIntroCameraCalls = 0;
        bCoopIntroRoleSent = False;
        bCoopIntroResumeCommitted = False;
        bCoopIntroOwnerTimeoutReported = False;
        CoopIntroOwnerDeadline = Level.TimeSeconds + 170;
        EnsureCoopIntroOwner();
    }
    CoopStoryView = SharedView;
    bCoopSceneLocalHold = True;
    bCoopSceneLocalEnterPending = True;
    bCoopSceneLocalReleasePending = False;
    bCoopSceneLocalResumeSent = False;
    bCoopSceneSawSimulated = False;
    CoopSceneOwnerTick();
}

function ServerCoopSceneCaptured(int Serial, float OwnerHoldStamp)
{
    local HPCoopGame G;
    G = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || G == None || !G.IsAliveCoopPlayer(self)
        || (G.StoryLeader != self && (G.IntroCoordinator == None
            || !G.IntroCoordinator.IsMember(self)))
        || !bCoopSceneMode || !bCoopStoryCaptured
        || Serial != CoopSceneSerial || bCoopSceneEnterArmed
        || RemoteRole != ROLE_AutonomousProxy) return;
    if (G.IntroCoordinator != None && G.IntroCoordinator.IsMember(self)
        && !G.IntroCoordinator.CanAcceptCapture(self)) return;
    if (!(OwnerHoldStamp >= 0) || !(Abs(OwnerHoldStamp) < 100000000)) return;
    CoopSceneOwnerHoldStamp = OwnerHoldStamp;
    CoopSceneServerHoldTime = Level.TimeSeconds;
    if (G.IntroCoordinator != None && G.IntroCoordinator.IsMember(self))
    {
        G.IntroCoordinator.Captured(self, Serial);
        if (self != G.StoryLeader) return;
    }
    bCoopSceneEnterArmed = True;
    CoopSceneArmTime = Level.TimeSeconds;
}

function CoopSceneAuthorityTick()
{
    local HPCoopGame G;
    G = HPCoopGame(Level.Game);
    if (!bCoopSceneMode || Role != ROLE_Authority) return;
    // Commit outside the RPC/native pawn tick, on a later world frame.
    if (bCoopSceneEnterArmed && bCoopStoryCaptured
        && Level.TimeSeconds > CoopSceneArmTime
        && (G == None || G.IntroCoordinator == None
            || G.IntroCoordinator.CanEnterAuthority(self)))
    {
        bCoopSceneEnterArmed = False;
        bClientAnim = False;
        RemoteRole = ROLE_SimulatedProxy;
        Log("[MP_CAPTURE_MODE] authority-native serial=" $ CoopSceneSerial
            $ " pawn=" $ self $ " state=" $ GetStateName() $ " location=" $ Location);
    }
    if (bCoopWalkIssued && !bCoopWalkCueReceived && !bCoopWalkBlocked
        && Level.TimeSeconds >= CoopWalkNextSample)
    {
        CoopWalkNextSample = Level.TimeSeconds + 0.25;
        Log("[MP_CAPTURE_WALK] sample pawn=" $ self $ " state=" $ GetStateName()
            $ " role=" $ Role $ " remote=" $ RemoteRole $ " physics=" $ Physics
            $ " location=" $ Location $ " velocity=" $ Velocity
            $ " acceleration=" $ Acceleration $ " goal=" $ CoopWalkGoal
            $ " distance-xy=" $ VSize2d(Location - CoopWalkGoal)
            $ " cue=" $ sCutNotifyCue $ " notify=" $ CutNotifyActor);
    }
}

function EndCoopAuthorityCapture()
{
    if (Role != ROLE_Authority || !bCoopSceneMode) return;
    bCoopSceneEnterArmed = False;
    bCoopSceneAwaitRelease = True;
    CoopSceneSerial++;
    RemoteRole = CoopSavedRemoteRole;
    bClientAnim = bCoopSavedClientAnim;
    Velocity = vect(0,0,0);
    Acceleration = vect(0,0,0);
    ClientCoopSceneRelease(CoopSceneSerial, Location, Rotation, Physics, CurrentTimeStamp);
    Log("[MP_CAPTURE_WALK] release issued=" $ bCoopWalkIssued
        $ " reached=" $ bCoopWalkReached $ " original-cue-received=" $ bCoopWalkCueReceived
        $ " blocked=" $ bCoopWalkBlocked $ " location=" $ Location
        $ " distance-xy=" $ VSize2d(Location - CoopWalkGoal));
}

simulated function ClientCoopSceneRelease(int Serial, vector Position,
    rotator Facing, EPhysics NewPhysics, float AuthorityTimeStamp)
{
    if (!IsLocalCoopPlayer() || bCoopIntroLocalFailed || Serial <= CoopLocalSceneSerial) return;
    CoopLocalSceneSerial = Serial;
    bCoopSceneLocalHold = True;
    bCoopSceneLocalEnterPending = False;
    bCoopSceneLocalReleasePending = True;
    bCoopSceneLocalResumeSent = False;
    CoopSceneReleaseLocation = Position;
    CoopSceneReleaseRotation = Facing;
    CoopSceneReleasePhysics = NewPhysics;
    CoopSceneReleaseStamp = AuthorityTimeStamp;
    CoopSceneOwnerTick();
}

simulated function bool CoopSceneOwnerTick()
{
    if (!IsLocalCoopPlayer() || !bCoopSceneLocalHold) return False;
    if (bCoopIntroLocalFailed) return True;
    if (Role == ROLE_SimulatedProxy && !bCoopSceneSawSimulated)
    {
        bCoopSceneSawSimulated = True;
        Log("[MP_CAPTURE_MODE] owner-simulated serial=" $ CoopLocalSceneSerial
            $ " role=" $ Role $ " physics=" $ Physics $ " location=" $ Location);
    }
    if (bCoopSceneLocalEnterPending && Role == ROLE_AutonomousProxy
        && bCoopReadySent && bLocalContextReady && myHUD != None
        && LocalCoopCamera != None && CoopStoryView != None && CoopStoryView.HasCoopView()
        && (!bCoopIntroLocalActive || (CoopIntroCameraCalls > 0
            && CoopStoryView.SceneSerial == CoopIntroViewSerial)))
    {
        // Run local presentation while normal autonomous script calls are legal.
        bCoopStoryCaptured = True;
        ApplyCoopCapturePresentation();
        ClearCoopPrediction();
        Velocity = vect(0,0,0);
        Acceleration = vect(0,0,0);
        SetPhysics(PHYS_None);
        bCoopSceneLocalEnterPending = False;
        ServerCoopSceneCaptured(CoopLocalSceneSerial, Level.TimeSeconds);
        Log("[MP_CAPTURE_MODE] owner-held serial=" $ CoopLocalSceneSerial
            $ " role=" $ Role $ " physics=" $ Physics $ " location=" $ Location);
    }
    if (bCoopSceneLocalReleasePending && Role == ROLE_AutonomousProxy
        && !bCoopSceneLocalResumeSent)
    {
        ClearCoopPrediction();
        // Network reconciliation of this owner's actual authority endpoint.
        // This runs after the independent server walk/cue evidence is recorded.
        if (!SetLocation(CoopSceneReleaseLocation))
        {
            Log("[MP_CAPTURE_MODE] BLOCKED reason=owner-release-position serial=" $ CoopLocalSceneSerial);
            bCoopSceneLocalReleasePending = False;
            return True;
        }
        SetRotation(CoopSceneReleaseRotation);
        ViewRotation = CoopSceneReleaseRotation;
        Velocity = vect(0,0,0);
        Acceleration = vect(0,0,0);
        SetPhysics(CoopSceneReleasePhysics);
        CurrentTimeStamp = FMax(CurrentTimeStamp, CoopSceneReleaseStamp);
        bPressedJump = False;
        bCoopSceneLocalResumeSent = True;
        ServerCoopSceneResumed(CoopLocalSceneSerial, Level.TimeSeconds, bJumpStatus);
        Log("[MP_CAPTURE_MODE] owner-role-restored serial=" $ CoopLocalSceneSerial
            $ " role=" $ Role $ " saw-simulated=" $ bCoopSceneSawSimulated
            $ " location=" $ Location);
    }
    return True;
}

function ServerCoopSceneResumed(int Serial, float OwnerResumeStamp, bool OwnerJumpStatus)
{
    local HPCoopGame G;
    G = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || G == None || !G.IsAliveCoopPlayer(self)
        || !bCoopSceneMode || !bCoopSceneAwaitRelease || bCoopStoryCaptured
        || Serial != CoopSceneSerial || RemoteRole != ROLE_AutonomousProxy) return;
    // The owner stamp is a chronological barrier, never a position authority.
    // Paired capture clocks allow generous jitter without accepting NaN,
    // infinity or a client timestamp arbitrarily far beyond this scene.
    if (!(Abs(OwnerResumeStamp) < 100000000) || !(OwnerResumeStamp >= CurrentTimeStamp)
        || !(OwnerResumeStamp >= CoopSceneOwnerHoldStamp)
        || !(OwnerResumeStamp <= CoopSceneOwnerHoldStamp
            + FMax(0, Level.TimeSeconds - CoopSceneServerHoldTime) + 5))
    {
        Log("[MP_CAPTURE_MODE] BLOCKED reason=resume-stamp serial=" $ Serial);
        return;
    }
    CurrentTimeStamp = FMax(CurrentTimeStamp, OwnerResumeStamp);
    CoopSceneResumeFloor = CurrentTimeStamp;
    ServerTimeStamp = Level.TimeSeconds;
    bJumpStatus = OwnerJumpStatus;
    bPressedJump = False;
    bCoopSceneAwaitRelease = False;
    bCoopSceneMode = False;
    PublishCoopStatus(True);
    ClientCoopSceneCommitted(Serial);
    Log("[MP_CAPTURE_MODE] resumed serial=" $ Serial $ " floor=" $ CoopSceneResumeFloor);
}

simulated function ClientCoopSceneCommitted(int Serial)
{
    if (!IsLocalCoopPlayer() || bCoopIntroLocalFailed || Serial != CoopLocalSceneSerial
        || !bCoopSceneLocalResumeSent || Role != ROLE_AutonomousProxy) return;
    ClearCoopPrediction();
    if (bCoopIntroLocalActive)
    {
        bCoopIntroResumeCommitted = True;
        bCoopSceneLocalReleasePending = False;
        return;
    }
    bCoopSceneLocalHold = False;
    bCoopSceneLocalReleasePending = False;
    bCoopStoryCaptured = False;
    ApplyCoopCapturePresentation();
    Log("[MP_CAPTURE_MODE] owner-resumed serial=" $ Serial $ " role=" $ Role);
}

function DoMoveTo(vector v0, optional bool bSnap, optional float Speed,
    optional vector v1, optional vector v2, optional vector v3, optional vector v4,
    optional name FinishState)
{
    local Actor Marker, ExpectedMarker;
    if (Role == ROLE_Authority && bCoopSceneMode && bCoopStoryCaptured)
    {
        bSnap = False;
        bCoopWalkIssued = True;
        bCoopWalkReached = False;
        bCoopWalkCueReceived = False;
        bCoopWalkBlocked = False;
        CoopWalkStart = Location;
        CoopWalkGoal = v0;
        CoopWalkNotify = CutNotifyActor;
        Log("[MP_CAPTURE_WALK] begin pawn=" $ self $ " start=" $ Location
            $ " goal=" $ v0 $ " physics=" $ Physics $ " notify=" $ CutNotifyActor);
        foreach AllActors(Class'Actor', Marker)
            if (Marker.CutName ~= "CutMark0")
            {
                ExpectedMarker = Marker;
                break;
            }
        if (ExpectedMarker == None || VSize(v0 - ExpectedMarker.Location) > 0.1)
        {
            bCoopWalkBlocked = True;
            Log("[MP_CAPTURE_WALK] BLOCKED reason=not-ch1-cutmark0");
            return;
        }
        if (v1 != vect(0,0,0) || v2 != vect(0,0,0) || v3 != vect(0,0,0) || v4 != vect(0,0,0))
        {
            bCoopWalkBlocked = True;
            Log("[MP_CAPTURE_WALK] BLOCKED reason=unsupported-multiple-waypoints");
            return;
        }
    }
    Super.DoMoveTo(v0, bSnap, Speed, v1, v2, v3, v4, FinishState);
}

function CoopOriginalWalkCueReceived(Actor Source, string Cue)
{
    if (!bCoopSceneMode || !bCoopWalkReached || bCoopWalkCueReceived
        || Source != CoopWalkNotify || Source != CutNotifyActor
        || Cue == "" || Cue != sCutNotifyCue) return;
    bCoopWalkCueReceived = True;
    Log("[MP_CAPTURE_WALK] original-cue-received cue=" $ Cue $ " notify=" $ Source
        $ " location=" $ Location $ " distance-xy=" $ VSize2d(Location - CoopWalkGoal));
}

state stateMovingToLoc
{
    function CutBypass()
    {
        if (bCoopSceneMode)
        {
            bCoopWalkBlocked = True;
            Log("[MP_CAPTURE_WALK] BLOCKED reason=cut-bypass-requested");
            GotoState('stateCutIdle');
            return;
        }
        Super.CutBypass();
    }

    function DoneWithMoveTo()
    {
        if (bCoopSceneMode && bCoopWalkIssued)
        {
            if (bCoopWalkBlocked || CutNotifyActor != CoopWalkNotify || CoopWalkNotify == None
                || VSize2d(Location - CoopWalkGoal) > FMax(16, CollisionRadius)
                || Abs(Location.Z - CoopWalkGoal.Z) > CollisionHeight
                || VSize2d(Location - CoopWalkStart) <= 1)
            {
                bCoopWalkBlocked = True;
                Log("[MP_CAPTURE_WALK] BLOCKED reason=native-walk-ended-without-arrival"
                    $ " location=" $ Location $ " goal=" $ CoopWalkGoal);
                GotoState('stateCutIdle');
                return;
            }
            bCoopWalkReached = True;
            Log("[MP_CAPTURE_WALK] original-done location=" $ Location
                $ " distance-xy=" $ VSize2d(Location - CoopWalkGoal)
                $ " moved-xy=" $ VSize2d(Location - CoopWalkStart));
        }
        Super.DoneWithMoveTo();
    }
}

state CoopDead
{
    ignores TakeDamage, Fire, AltFire, DoJump, ZoneChange, HeadZoneChange,
        FootZoneChange, Landed, PainTimer;

    function PlayerMove(float DeltaTime) {}
    function ServerReStartPlayer() {}
    function PlayerTick(float DeltaTime)
    {
        if (IsLocalCoopPlayer()) EnsureLocalCoopContext();
    }
    function CoopAuthorityMovementTick(float DeltaTime)
    {
        local float PresentationDelay;
        if (Role != ROLE_Authority || bCoopDeathAnimFinished) return;
        // M212 skips latent ProcessState on authority pawns whose RemoteRole
        // is AutonomousProxy. Observe the real animation from the Game pass;
        // never advance AnimFrame or synthesize FinishAnim.
        if (CoopDeathAnimationEndedAt < 0)
        {
            if (!bInstantDeath && (AnimSequence != 'faint' || IsAnimating())) return;
            CoopDeathAnimationEndedAt = Level.TimeSeconds;
            Log("[MP_DEATH] presentation-ended pawn=" $ self $ " instant=" $ bInstantDeath
                $ " anim=" $ AnimSequence $ " frame=" $ AnimFrame);
        }
        PresentationDelay = 0.5;
        if (bSlowDeath) PresentationDelay += 1.5;
        if (Level.TimeSeconds - CoopDeathAnimationEndedAt >= PresentationDelay)
            bCoopDeathAnimFinished = True;
    }
    function BeginState()
    {
        local float FaintRate;
        SetPhysics(PHYS_None);
        SetBase(None);
        SetCollision(False, False, False);
        HarryAnimType = AT_Replace;
        Velocity = vect(0,0,0);
        Acceleration = vect(0,0,0);
        if (bInstantDeath) bHidden = True;
        else
        {
            FaintRate = 1.0;
            if (bClubDeath) FaintRate = 1.5;
            PlayAnim('faint', FaintRate, 0.2);
            if (bClubDeath) AnimFrame = 36.0 / 151.0;
            if (Role == ROLE_Authority) PlayDeathEmoteSound();
        }
    }
begin:
    Stop;
}

// Hard-coded legacy state transitions must not reach its latent LoadGame loop.
state stateDead
{
    function BeginState()
    {
        if (Role == ROLE_Authority) Global.KillHarry(True);
        if (bCoopDead) GotoState('CoopDead');
        else GotoState('PlayerWalking');
    }
begin:
    Stop;
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
