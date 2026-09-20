// Disposable diagnostic. Selected only by explicit Ch1 MountRootB0/B1 probe.
// Never a replacement default player for ordinary co-op.
class HPCoopMountTrialHarry extends HPCoopHarry;

var HPCoopMountRootProbe MountProbe;
var HPCoopMovementState TrialSnapshot;
var bool bTrialActive, bTrialArm, bTrialInvoking, bTrialNative, bTrialExit;
var bool bTrialFailed, bTrialHeld, bTrialReleasePending, bTrialResumeSent;
var bool bTrialSawRole2, bTrialSavedClientAnim;
var bool bTrialPolicyArmed, bTrialPolicyB1;
var ENetRole TrialSavedRole;
var int TrialSerial, TrialLocalSerial, TrialLife;
var int TrialMountingCount, TrialShrinkCount, TrialRestoreCount, TrialResidualCount;
var int TrialDuplicateResiduals, TrialWitnessSerial;
var float TrialArmTime, TrialEntryTime, TrialExitTime, TrialResumeFloor;
var float TrialOwnerHoldTime, TrialServerHoldTime, TrialLastResidualTime;
var float TrialRadius, TrialHeight, TrialWidth, TrialDeadline;
var vector TrialPrePivot, TrialDelta;
var string TrialFailure;
var bool bTrialSawFrameChange;
var float TrialLastFrame, TrialResidualDistance;
var name TrialLastSequence;
var vector TrialReleasePosition, TrialReleasePrePivot;
var rotator TrialReleaseRotation;
var Actor TrialReleaseBase;
var EPhysics TrialReleasePhysics;
var float TrialReleaseRadius, TrialReleaseHeight, TrialReleaseWidth, TrialReleaseStamp;
var name TrialReleaseIdle;
var HPCoopMountTrialHarry TrialObserved;
var name TrialRootBone, TrialPelvisBone, TrialFootBone;
var bool bTrialBonesValid;
var float TrialNextSample, TrialObserveUntil;

replication
{
    reliable if (Role == ROLE_Authority)
        TrialSnapshot, ClientMountObserve, ClientMountPrepare,
        ClientMountRelease, ClientMountCommit, ClientMountStopObserve;
    reliable if (Role < ROLE_Authority)
        ServerMountWitness, ServerMountHeld, ServerMountResumed;
}

function bool TrialEligible()
{
    local HPCoopGame G;
    G = HPCoopGame(Level.Game);
    return Role == ROLE_Authority && Level.NetMode == NM_DedicatedServer
        && G != None && ((G.RuntimeProbe ~= "MountRootB0") || (G.RuntimeProbe ~= "MountRootB1"))
        && (G.TestStage ~= "RictusempraLessonComplete")
        && (string(Level.Outer.Name) ~= "Ch1Rictusempra")
        && !G.bCoopRecoveryBlocked && !G.bStoryCaptured
        && G.IntroCoordinator != None && G.IntroCoordinator.Phase == 5
        && G.IsAliveCoopPlayer(self) && !bCoopStoryCaptured && !bCoopDead
        && !bCoopAwaitResume && !bCoopSceneMode && !bCoopSceneLocalHold
        && !bCoopSceneAwaitRelease && !bCoopIntroInputHold
        && Level.Pauser == "";
}

function TrialFail(string Reason)
{
    if (bTrialFailed) return;
    bTrialFailed = True;
    TrialFailure = Reason;
    Log("[MP_MOUNT_TRIAL] BLOCKED pawn=" $ self $ " reason=" $ Reason
        $ " state=" $ GetStateName() $ " role=" $ Role $ " remote=" $ RemoteRole);
    // Do not synthesize EndState/completion or an endpoint. The disposable run
    // remains held for inspection; the operator stops it. Native state is left
    // alone if already running. Never resume a partially restored capsule.
}

simulated function ClientMountObserve(int Serial, HPCoopMountTrialHarry Subject, bool B1)
{
    if (!IsLocalCoopPlayer() || Role != ROLE_AutonomousProxy || Subject == None
        || !(string(Level.Outer.Name) ~= "Ch1Rictusempra") || Serial <= TrialWitnessSerial)
        return;
    TrialWitnessSerial = Serial;
    TrialObserved = Subject;
    TrialObserveUntil = 0;
    TrialNextSample = 0;
    Subject.bTrialPolicyArmed = True;
    Subject.bTrialPolicyB1 = B1;
    TrialRootBone = Subject.BoneName(0);
    TrialPelvisBone = 'bip01 pelvis';
    TrialFootBone = 'bip01 l foot';
    bTrialBonesValid = Subject.Mesh != None && TrialRootBone != ''
        && Subject.BoneNumber(TrialRootBone) >= 0
        && Subject.BoneNumber(TrialPelvisBone) >= 0
        && Subject.BoneNumber(TrialFootBone) >= 0;
    Log("[MP_MOUNT_WITNESS] armed viewer=" $ self $ " subject=" $ Subject
        $ " serial=" $ Serial $ " variantB1=" $ B1 $ " bones=" $ bTrialBonesValid
        $ " root=" $ TrialRootBone $ " pelvis=" $ TrialPelvisBone $ " foot=" $ TrialFootBone);
    ServerMountWitness(Serial, Subject, bTrialBonesValid);
}

function ServerMountWitness(int Serial, HPCoopMountTrialHarry Subject, bool BonesValid)
{
    local HPCoopMountRootProbe P;
    foreach AllActors(Class'HPCoopMountRootProbe', P)
        P.Witness(self, Serial, Subject, BonesValid);
}

function bool PrepareMountTrial(HPCoopMountRootProbe P, int Serial, vector Delta)
{
    if (!TrialEligible() || P == None || Serial <= 0 || bTrialActive
        || !IsInState('PlayerWalking') || Physics != PHYS_Walking
        || Base != Level || CarryingActor != None || Abs(CollisionWidth) > 0.001)
        return False;
    MountProbe = P;
    TrialSerial = Serial;
    TrialLife = CoopLifeSerial;
    TrialDelta = Delta;
    TrialRadius = CollisionRadius;
    TrialHeight = CollisionHeight;
    TrialWidth = CollisionWidth;
    TrialPrePivot = PrePivot;
    TrialSavedRole = RemoteRole;
    bTrialSavedClientAnim = bClientAnim;
    if (TrialSavedRole != ROLE_AutonomousProxy) return False;
    bTrialActive = True;
    TrialDeadline = Level.TimeSeconds + 20;
    TrialLastResidualTime = -1;
    ClientMountPrepare(Serial, CoopLifeSerial);
    Log("[MP_MOUNT_TRIAL] prepare serial=" $ Serial $ " pawn=" $ self
        $ " delta=" $ Delta $ " location=" $ Location $ " capsule=" $ CollisionRadius
        $ "," $ CollisionHeight $ "," $ CollisionWidth $ " prepivot=" $ PrePivot);
    return True;
}

simulated function ClientMountPrepare(int Serial, int Life)
{
    if (!IsLocalCoopPlayer() || Serial <= TrialLocalSerial
        || Life != CoopLifeSerial || Role != ROLE_AutonomousProxy
        || !bLocalContextReady || LocalCoopCamera == None || Mesh == None
        || !IsInState('PlayerWalking') || bCoopStoryCaptured || bCoopDead
        || bCoopSceneLocalHold || TrialObserved != self || !bTrialBonesValid)
    {
        Log("[MP_MOUNT_TRIAL] BLOCKED reason=owner-prepare-context serial=" $ Serial);
        return;
    }
    TrialLocalSerial = Serial;
    bTrialHeld = True;
    bTrialSawRole2 = False;
    bTrialResumeSent = False;
    bTrialReleasePending = False;
    Log("[MP_MOUNT_STOP] before seq=" $ AnimSequence $ " frame=" $ AnimFrame
        $ " rate=" $ AnimRate $ " move=" $ bAnimMove $ " aux=" $ AuxAnims.Length
        $ " capsule=" $ CollisionRadius $ "," $ CollisionHeight $ "," $ CollisionWidth
        $ " prepivot=" $ PrePivot);
    // Does not restore capsule or claim a same-pose freeze. No local Mount was
    // entered in this diagnostic. Preserve upper-body channel objects.
    PlayAnim('None', 0, 0, AT_Combine);
    ClearCoopPrediction();
    Velocity = vect(0,0,0);
    Acceleration = vect(0,0,0);
    SetPhysics(PHYS_None);
    Log("[MP_MOUNT_STOP] after seq=" $ AnimSequence $ " frame=" $ AnimFrame
        $ " rate=" $ AnimRate $ " move=" $ bAnimMove $ " aux=" $ AuxAnims.Length
        $ " capsule=" $ CollisionRadius $ "," $ CollisionHeight $ "," $ CollisionWidth
        $ " prepivot=" $ PrePivot);
    // M212 retains the previous numeric rate after PlayAnim('None'). With no
    // active sequence and no move bit, that stale value cannot drive a clip.
    if (AnimSequence != '' || bAnimMove)
    { Log("[MP_MOUNT_TRIAL] BLOCKED reason=native-stop-postcondition"); return; }
    ServerMountHeld(Serial, Life, Level.TimeSeconds);
}

function ServerMountHeld(int Serial, int Life, float Stamp)
{
    if (!TrialEligible() || !bTrialActive || bTrialArm || bTrialNative
        || Serial != TrialSerial || Life != TrialLife || Life != CoopLifeSerial
        || !IsInState('PlayerWalking') || RemoteRole != ROLE_AutonomousProxy
        || !(Stamp >= 0) || !(Abs(Stamp) < 100000000)) return;
    TrialOwnerHoldTime = Stamp;
    TrialServerHoldTime = Level.TimeSeconds;
    TrialArmTime = Level.TimeSeconds;
    bTrialArm = True;
    Log("[MP_MOUNT_TRIAL] held-ack serial=" $ Serial $ " stamp=" $ Stamp);
}

function CoopAuthorityTick(float DeltaTime)
{
    Super.CoopAuthorityTick(DeltaTime);
    if (!bTrialActive || Role != ROLE_Authority || bTrialFailed) return;
    if (!TrialEligible() || CoopLifeSerial != TrialLife)
    { TrialFail("life-scene-or-pause-interrupted"); return; }
    if (Level.TimeSeconds > TrialDeadline) { TrialFail("timeout-held-for-inspection"); return; }
    if (bTrialArm && Level.TimeSeconds > TrialArmTime)
    {
        bTrialArm = False;
        bTrialInvoking = True;
        // The ONLY fixture event. Original Mounting.BeginState and all latent
        // source are inherited; no GotoState to a phase, PlayAnim or physics step.
        Mount(TrialDelta);
        bTrialInvoking = False;
        TrialEntryTime = Level.TimeSeconds;
        if (!IsInState('Mounting') || TrialMountingCount != 1)
        { TrialFail("original-mount-entry-not-observed"); return; }
        TrialSnapshot = Spawn(Class'HPCoopMovementState', self);
        if (TrialSnapshot == None) { TrialFail("snapshot-spawn"); return; }
        TrialSnapshot.BeginSnapshot(self, 'Mounting');
        return;
    }
    if (!bTrialNative && TrialMountingCount == 1 && Level.TimeSeconds > TrialEntryTime)
    {
        bClientAnim = False;
        RemoteRole = ROLE_SimulatedProxy;
        bTrialNative = True;
        Log("[MP_MOUNT_TRIAL] native-role serial=" $ TrialSerial $ " state=" $ GetStateName());
    }
    if (bTrialExit && Level.TimeSeconds > TrialExitTime)
    {
        bTrialExit = False;
        TrialSnapshot.EndSnapshot('OriginalWalking');
        ClientMountRelease(TrialSerial, Location, Rotation, Base, Physics,
            CollisionRadius, CollisionHeight, CollisionWidth, PrePivot,
            AnimSequence, CurrentTimeStamp);
        Log("[MP_MOUNT_TRIAL] final-after-native-tail serial=" $ TrialSerial
            $ " location=" $ Location $ " seq=" $ AnimSequence $ " physics=" $ Physics
            $ " restore=" $ TrialRestoreCount $ " residualCalls=" $ TrialResidualCount
            $ " duplicate=" $ TrialDuplicateResiduals $ " residualDistance=" $ TrialResidualDistance);
    }
}

event Mount(vector Delta)
{
    if (Role == ROLE_Authority && bTrialInvoking && bTrialActive)
        Super.Mount(Delta);
    else
        Log("[MP_MOUNT_TRIAL] non-fixture-mount-suppressed role=" $ Role);
}

state Mounting
{
    function BeginState()
    {
        Super.BeginState();
        if (bTrialActive && Role == ROLE_Authority)
        {
            TrialMountingCount++;
            Log("[MP_MOUNT_TRIAL] original-mounting-begin physics=" $ Physics $ " base=" $ Base);
        }
    }
    // No label: retain the original inherited begin bytecode.
}

state MountFinish
{
    function BeginState()
    {
        Super.BeginState();
        if (!bTrialActive || Role != ROLE_Authority) return;
        TrialShrinkCount++;
        TrialLastFrame = AnimFrame;
        TrialLastSequence = AnimSequence;
        Log("[MP_MOUNT_TRIAL] original-shrink seq=" $ AnimSequence
            $ " move=" $ bAnimMove $ " residual=" $ MountDelta
            $ " capsule=" $ CollisionRadius $ "," $ CollisionHeight $ "," $ CollisionWidth
            $ " prepivot=" $ PrePivot);
        if (TrialShrinkCount != 1 || Abs(CollisionRadius - TrialRadius * 0.5) > 0.01
            || Abs(CollisionHeight - TrialHeight * 0.5) > 0.01
            || Abs(CollisionWidth - TrialHeight * 0.5) > 0.01
            || VSize(PrePivot - (TrialPrePivot - vect(0,0,1) * (TrialHeight * 0.5))) > 0.01
            || AnimSequence != 'climb32' || !bAnimMove || Abs(MountDelta.Z) > 0.01)
            TrialFail("original-shrink-or-climb32-contract");
    }

    event PlayerTick(float DeltaTime)
    {
        local vector Before;
        if (Role != ROLE_Authority || !bTrialActive || !bTrialNative) return;
        if (TrialLastResidualTime == Level.TimeSeconds)
        {
            TrialDuplicateResiduals++;
            TrialFail("duplicate-native-residual-dispatch");
            return;
        }
        TrialLastResidualTime = Level.TimeSeconds;
        TrialResidualCount++;
        Before = Location;
        // Native Actor::Tick provides the only call. Never call via Game Tick.
        Super.PlayerTick(DeltaTime);
        TrialResidualDistance += VSize(Location - Before);
        if (AnimSequence == TrialLastSequence && AnimFrame != TrialLastFrame)
            bTrialSawFrameChange = True;
        TrialLastSequence = AnimSequence;
        TrialLastFrame = AnimFrame;
        Log("[MP_MOUNT_AUTH] time=" $ Level.TimeSeconds $ " dt=" $ DeltaTime
            $ " loc=" $ Location $ " seq=" $ AnimSequence $ " frame=" $ AnimFrame
            $ " rate=" $ AnimRate $ " move=" $ bAnimMove $ " role=" $ Role
            $ " remote=" $ RemoteRole $ " residualStep=" $ VSize(Location - Before));
    }

    function EndState()
    {
        Super.EndState();
        if (!bTrialActive || Role != ROLE_Authority) return;
        TrialRestoreCount++;
        Log("[MP_MOUNT_TRIAL] original-restore capsule=" $ CollisionRadius
            $ "," $ CollisionHeight $ "," $ CollisionWidth $ " prepivot=" $ PrePivot);
        if (TrialRestoreCount != 1 || Abs(CollisionRadius - TrialRadius) > 0.01
            || Abs(CollisionHeight - TrialHeight) > 0.01 || Abs(CollisionWidth) > 0.01
            || VSize(PrePivot - TrialPrePivot) > 0.01)
            TrialFail("original-restore-contract");
    }
    // No begin/FinishAnim replacement; no Game-driven residual or physics.
}

function ServerMove(float TimeStamp, vector InAccel, vector ClientLoc,
    bool NewbRun, bool NewbDuck, bool NewbJumpStatus, bool bFired,
    bool bAltFired, bool bForceFire, bool bForceAltFire, eDodgeDir DodgeMove,
    byte ClientRoll, int View, optional byte OldTimeDelta, optional int OldAccel)
{
    // This fixture starts only AFTER the reliable hold, outside ServerMove.
    // No claim that it exercises the collision-driven OldMove boundary.
    if (bTrialActive || TimeStamp <= TrialResumeFloor) return;
    Super.ServerMove(TimeStamp, InAccel, ClientLoc, NewbRun, NewbDuck,
        NewbJumpStatus, bFired, bAltFired, bForceFire, bForceAltFire,
        DodgeMove, ClientRoll, View, OldTimeDelta, OldAccel);
}

function ClientAdjustPosition(float TimeStamp, name NewState, EPhysics NewPhysics,
    float NewLocX, float NewLocY, float NewLocZ,
    float NewVelX, float NewVelY, float NewVelZ, Actor NewBase)
{
    if (bTrialHeld || NewState == 'Mounting' || NewState == 'MountFinish'
        || TimeStamp <= TrialResumeFloor) return;
    Super.ClientAdjustPosition(TimeStamp, NewState, NewPhysics,
        NewLocX, NewLocY, NewLocZ, NewVelX, NewVelY, NewVelZ, NewBase);
}

function ClientUpdatePosition()
{
    if (!bTrialHeld) Super.ClientUpdatePosition();
}

simulated function ClientMountRelease(int Serial, vector Position, rotator Facing,
    Actor FinalBase, EPhysics FinalPhysics, float R, float H, float W,
    vector Pivot, name Idle, float Stamp)
{
    if (!IsLocalCoopPlayer() || !bTrialHeld || Serial != TrialLocalSerial) return;
    TrialReleasePosition = Position;
    TrialReleaseRotation = Facing;
    TrialReleaseBase = FinalBase;
    TrialReleasePhysics = FinalPhysics;
    TrialReleaseRadius = R;
    TrialReleaseHeight = H;
    TrialReleaseWidth = W;
    TrialReleasePrePivot = Pivot;
    TrialReleaseIdle = Idle;
    TrialReleaseStamp = Stamp;
    bTrialReleasePending = True;
    TrialOwnerTick();
}

simulated function bool TrialOwnerTick()
{
    if (!IsLocalCoopPlayer() || !bTrialHeld) return False;
    bPressedJump = False;
    bAltFire = 0; bFire = 0;
    aForward = 0; aStrafe = 0; aTurn = 0; aLookUp = 0;
    if (Role == ROLE_SimulatedProxy && !bTrialSawRole2)
    {
        bTrialSawRole2 = True;
        Log("[MP_MOUNT_TRIAL] owner-role2 location=" $ Location $ " physics=" $ Physics);
    }
    if (bTrialReleasePending && Role == ROLE_AutonomousProxy && !bTrialResumeSent)
    {
        // Log the actual native receiver BEFORE any endpoint reconciliation.
        Log("[MP_MOUNT_PRE_RECONCILE] serial=" $ TrialLocalSerial
            $ " actorError=" $ VSize(Location - TrialReleasePosition)
            $ " radiusError=" $ Abs(CollisionRadius - TrialReleaseRadius)
            $ " heightError=" $ Abs(CollisionHeight - TrialReleaseHeight)
            $ " widthError=" $ Abs(CollisionWidth - TrialReleaseWidth)
            $ " pivotError=" $ VSize(PrePivot - TrialReleasePrePivot)
            $ " sawRole2=" $ bTrialSawRole2 $ " seq=" $ AnimSequence $ " frame=" $ AnimFrame);
        if (!bTrialSawRole2 || TrialReleaseIdle == '' || !HasAnim(TrialReleaseIdle))
        { Log("[MP_MOUNT_TRIAL] BLOCKED reason=release-role-or-idle"); return True; }
        ClearCoopPrediction();
        SetCollisionSize(TrialReleaseRadius, TrialReleaseHeight, TrialReleaseWidth);
        PrePivot = TrialReleasePrePivot;
        if (!SetLocation(TrialReleasePosition))
        {
            bTrialReleasePending = False;
            Log("[MP_MOUNT_TRIAL] BLOCKED reason=release-position-no-retry");
            return True;
        }
        SetRotation(TrialReleaseRotation);
        ViewRotation = TrialReleaseRotation;
        Velocity = vect(0,0,0); Acceleration = vect(0,0,0);
        SetPhysics(TrialReleasePhysics);
        SetBase(TrialReleaseBase);
        PlayAnim(TrialReleaseIdle, 1, 0.2, AT_Combine);
        CurrentTimeStamp = FMax(CurrentTimeStamp, TrialReleaseStamp);
        TrialResumeFloor = FMax(CurrentTimeStamp, Level.TimeSeconds);
        bTrialResumeSent = True;
        ServerMountResumed(TrialLocalSerial, TrialResumeFloor, bJumpStatus);
    }
    return True;
}

function ServerMountResumed(int Serial, float Stamp, bool JumpStatus)
{
    if (!TrialEligible() || !bTrialActive || bTrialFailed || bTrialExit
        || TrialRestoreCount != 1 || !IsInState('PlayerWalking')
        || Serial != TrialSerial || RemoteRole != ROLE_AutonomousProxy
        || TrialSnapshot == None || TrialSnapshot.bActive) return;
    if (!(Abs(Stamp) < 100000000) || !(Stamp >= CurrentTimeStamp)
        || !(Stamp >= TrialOwnerHoldTime)
        || !(Stamp <= TrialOwnerHoldTime + FMax(0, Level.TimeSeconds - TrialServerHoldTime) + 5))
    { TrialFail("resume-stamp"); return; }
    CurrentTimeStamp = Stamp;
    TrialResumeFloor = Stamp;
    ServerTimeStamp = Level.TimeSeconds;
    bJumpStatus = JumpStatus;
    bPressedJump = False;
    bTrialActive = False;
    ClientMountCommit(Serial);
    Log("[MP_MOUNT_TRIAL] resumed serial=" $ Serial $ " floor=" $ Stamp);
}

simulated function ClientMountCommit(int Serial)
{
    if (!IsLocalCoopPlayer() || Serial != TrialLocalSerial
        || !bTrialResumeSent || Role != ROLE_AutonomousProxy) return;
    ClearCoopPrediction();
    bTrialHeld = False;
    bTrialReleasePending = False;
    bTrialPolicyArmed = False;
    Log("[MP_MOUNT_TRIAL] owner-committed serial=" $ Serial);
}

simulated function TrialVisualPolicy()
{
    if (Role != ROLE_SimulatedProxy || !bTrialPolicyArmed) return;
    // B1 changes only the missing mode bit, not sequence/frame/rate/position.
    // Native dirty-cache timing remains measured, not forced.
    bAnimMove = bTrialPolicyB1 && (AnimSequence == 'climb32'
        || AnimSequence == 'climb64' || AnimSequence == 'climb96start'
        || AnimSequence == 'climb96end');
}

simulated function TrialSample()
{
    local HPCoopMountTrialHarry H;
    local vector RootPos, PelvisPos, FootPos;
    local int SnapshotNumber;
    if (!IsLocalCoopPlayer() || TrialObserved == None || !bTrialBonesValid) return;
    if (TrialObserveUntil > 0 && Level.TimeSeconds > TrialObserveUntil)
    { TrialObserved.bTrialPolicyArmed = False; TrialObserved = None; return; }
    if (Level.TimeSeconds < TrialNextSample) return;
    TrialNextSample = Level.TimeSeconds + 0.03333333;
    H = TrialObserved;
    H.TrialVisualPolicy();
    // Native bone queries may evaluate the mesh. Never treat polling as proof
    // of render order; capture visible output and repeat without these reads.
    RootPos = H.BonePos(TrialRootBone);
    PelvisPos = H.BonePos(TrialPelvisBone);
    FootPos = H.BonePos(TrialFootBone);
    if (H.TrialSnapshot != None) SnapshotNumber = H.TrialSnapshot.SnapshotSerial;
    Log("[MP_MOUNT_POSE] viewer=" $ self $ " subject=" $ H $ " serial=" $ TrialWitnessSerial
        $ " time=" $ Level.TimeSeconds $ " snapshot=" $ SnapshotNumber
        $ " role=" $ H.Role $ " remote=" $ H.RemoteRole $ " phys=" $ H.Physics
        $ " state=" $ H.GetStateName() $ " loc=" $ H.Location $ " vel=" $ H.Velocity
        $ " rot=" $ H.Rotation $ " base=" $ H.Base $ " mesh=" $ H.Mesh
        $ " scale=" $ H.DrawScale $ " capsule=" $ H.CollisionRadius $ "," $ H.CollisionHeight
        $ "," $ H.CollisionWidth $ " pivot=" $ H.PrePivot);
    Log("[MP_MOUNT_BONES] viewer=" $ self $ " subject=" $ H $ " time=" $ Level.TimeSeconds
        $ " snapshot=" $ SnapshotNumber $ " seq=" $ H.AnimSequence
        $ " frame=" $ H.AnimFrame $ " rate=" $ H.AnimRate $ " tween=" $ H.TweenRate
        $ " move=" $ H.bAnimMove $ " loop=" $ H.bAnimLoop $ " lastRoot=" $ H.LastAnimMove
        $ " root=" $ RootPos $ " pelvis=" $ PelvisPos $ " foot=" $ FootPos
        $ " rootLocal=" $ ((RootPos - H.Location) << H.Rotation));
    if (LocalCoopCamera != None)
        Log("[MP_MOUNT_CAMERA] viewer=" $ self $ " time=" $ Level.TimeSeconds
            $ " location=" $ LocalCoopCamera.Location $ " rotation=" $ LocalCoopCamera.Rotation);
}

simulated function ClientMountStopObserve(int Serial)
{
    if (!IsLocalCoopPlayer() || Serial != TrialWitnessSerial) return;
    TrialObserveUntil = Level.TimeSeconds + 1;
}

simulated event Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    TrialVisualPolicy();
    TrialOwnerTick();
    TrialSample();
}

simulated function PlayerTick(float DeltaTime)
{
    TrialSample();
    if (TrialOwnerTick()) return;
    Super.PlayerTick(DeltaTime);
}

event PlayerInput(float DeltaTime)
{
    if (TrialOwnerTick()) return;
    Super.PlayerInput(DeltaTime);
}

simulated event PlayerCalcView(out Actor ViewActor, out vector CameraLocation, out rotator CameraRotation)
{
    if (bTrialHeld && IsLocalCoopPlayer() && LocalCoopCamera != None)
    {
        ViewActor = LocalCoopCamera;
        CameraLocation = LocalCoopCamera.Location;
        CameraRotation = LocalCoopCamera.Rotation;
        return;
    }
    Super.PlayerCalcView(ViewActor, CameraLocation, CameraRotation);
}

function ServerCastCoopSpell(Actor Target, vector TargetOffset)
{
    if (!bTrialActive) Super.ServerCastCoopSpell(Target, TargetOffset);
}

function ServerCoopDrinkPotion()
{
    if (!bTrialActive) Super.ServerCoopDrinkPotion();
}

exec function AltFire(optional float F)
{
    if (!bTrialHeld) Super.AltFire(F);
}

function makeTarget()
{
    if (!bTrialHeld) Super.makeTarget();
}

function OnHarryProcessMoveComplete()
{
    if (!bTrialHeld) Super.OnHarryProcessMoveComplete();
}

function Cast()
{
    if (!bTrialHeld) Super.Cast();
}

function PlayIdle()
{
    if (!bTrialHeld) Super.PlayIdle();
}

function PlayWaiting()
{
    if (!bTrialHeld) Super.PlayWaiting();
}

function TweenToWaiting(float TweenTime)
{
    if (!bTrialHeld) Super.TweenToWaiting(TweenTime);
}

state PlayerWalking
{
    function CoopAuthorityMovementTick(float DeltaTime)
    {
        if (!bTrialActive) Super.CoopAuthorityMovementTick(DeltaTime);
    }

    simulated event PlayerTick(float DeltaTime)
    {
        TrialSample();
        if (TrialOwnerTick()) return;
        Super.PlayerTick(DeltaTime);
    }

    function PlayerMove(float DeltaTime)
    {
        if (!bTrialHeld) Super.PlayerMove(DeltaTime);
    }

    function AnimEnd()
    {
        if (!bTrialHeld) Super.AnimEnd();
    }

    function StartAiming(bool bUsingSword)
    {
        if (!bTrialHeld) Super.StartAiming(bUsingSword);
    }

    function BeginState()
    {
        Super.BeginState();
        if (Role != ROLE_Authority || !bTrialActive || TrialMountingCount == 0) return;
        if (TrialRestoreCount != 1 || TrialShrinkCount != 1 || !bTrialNative)
        { TrialFail("walking-without-original-mount-cleanup"); return; }
        TrialExitTime = Level.TimeSeconds;
        bTrialExit = True;
        RemoteRole = TrialSavedRole;
        bClientAnim = bTrialSavedClientAnim;
        Log("[MP_MOUNT_TRIAL] original-walking time=" $ TrialExitTime
            $ " loc=" $ Location $ " physics=" $ Physics $ " seq=" $ AnimSequence);
    }
}
