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

replication
{
    reliable if (Role == ROLE_Authority)
        CoopSlot, ClientCoopReady, bCoopStoryCaptured, ClientCoopCapture, ClientCoopSubtitle,
        CoopCampaignState, ClientCoopStatus, ClientCoopLife,
        ClientCoopDrinkPotion, ClientCoopKnockBack;
    reliable if (Role < ROLE_Authority)
        ServerCoopReady, ServerCastCoopSpell, ServerCoopDrinkPotion, ServerCoopResume;
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
    if (Role == ROLE_Authority && (bCoopStoryCaptured || bCoopDead || bCoopAwaitResume))
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

function ClientAdjustPosition(float TimeStamp, name NewState, EPhysics NewPhysics,
    float NewLocX, float NewLocY, float NewLocZ,
    float NewVelX, float NewVelY, float NewVelZ, Actor NewBase)
{
    // A correction queued before death must not re-enter walking or replay
    // prediction. Only the reliable lifecycle message can revive this owner.
    if (bCoopDead || bCoopStoryCaptured || NewState == 'CoopDead' || NewState == 'stateDead')
        return;
    Super.ClientAdjustPosition(TimeStamp, NewState, NewPhysics,
        NewLocX, NewLocY, NewLocZ, NewVelX, NewVelY, NewVelZ, NewBase);
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
    if (bCoopStoryCaptured || bCoopDead)
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
    // Native real player pawns dispatch PlayerTick instead of this event.
    // Authority maintenance is called once from HPCoopGame.Tick.
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
        if (IsLocalCoopPlayer() && !bCoopDead && !bCoopStoryCaptured
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
