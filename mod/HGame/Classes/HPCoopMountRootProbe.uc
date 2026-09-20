// Explicit Ch1 fixture: tests inherited authority states, not ledge detection.
class HPCoopMountRootProbe extends Info;

var HPCoopGame CoopGame;
var HPCoopMountTrialHarry Subject, Witnesses[2];
var bool bSawCapture, bObserveSent, bStarted, bFinished;
var byte bWitnessReady[2], bWitnessBones[2];
var int Serial;
var float Deadline, ReleasedAt;
var name RootBone, PelvisBone, FootBone;
var float NextAuthoritySample;

event PostBeginPlay()
{
    Super.PostBeginPlay();
    CoopGame = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || Level.NetMode != NM_DedicatedServer || CoopGame == None
        || !((CoopGame.RuntimeProbe ~= "MountRootB0") || (CoopGame.RuntimeProbe ~= "MountRootB1"))
        || !(CoopGame.TestStage ~= "RictusempraLessonComplete")
        || !(string(Level.Outer.Name) ~= "Ch1Rictusempra"))
    { Destroy(); return; }
    Serial = 1;
    Deadline = Level.TimeSeconds + 180;
    ReleasedAt = -1;
    SetTimer(0.1, True);
    Log("[MP_PROBE] probe=mount-root status=ARMED variant=" $ CoopGame.RuntimeProbe
        $ " fixture=True natural-ledge=False oldmove=False visual-pass=False");
}

function Finish(string Result, string Detail)
{
    local byte I;
    if (bFinished) return;
    bFinished = True;
    SetTimer(0, False);
    for (I = 0; I < 2; I++)
        if (Witnesses[I] != None) Witnesses[I].ClientMountStopObserve(Serial);
    Log("[MP_PROBE] probe=mount-root result=" $ Result $ " detail=" $ Detail
        $ " natural-ledge=False oldmove=False root-native-calls=NOT_MEASURED"
        $ " visual-pass=False two-pc=False");
}

function bool ReadyPair()
{
    local byte I;
    if (CoopGame.bWaitingForPlayers || CoopGame.CampaignState == None
        || !CoopGame.CampaignState.bIsTestStage) return False;
    for (I = 0; I < 2; I++)
    {
        Witnesses[I] = HPCoopMountTrialHarry(CoopGame.CoopPlayers[I]);
        if (!CoopGame.IsAliveCoopPlayer(Witnesses[I]) || CoopGame.ReadyPlayers[I] == 0
            || Witnesses[I].Player == None || Viewport(Witnesses[I].Player) != None)
            return False;
    }
    return Witnesses[0] != Witnesses[1];
}

function Witness(HPCoopMountTrialHarry Viewer, int SeenSerial,
    HPCoopMountTrialHarry SeenSubject, bool BonesValid)
{
    local byte I;
    if (bFinished || !bObserveSent || SeenSerial != Serial || SeenSubject != Subject) return;
    for (I = 0; I < 2; I++)
        if (Viewer == Witnesses[I])
        {
            bWitnessReady[I] = 1;
            if (BonesValid) bWitnessBones[I] = 1;
            Log("[MP_PROBE] probe=mount-root witness=" $ I $ " bones=" $ BonesValid);
        }
}

function bool ClearExistingVolume(HPCoopHarry H, vector Forward)
{
    local vector Extent, HitLocation, HitNormal, FinishPoint;
    local BoundingBox Corridor, OtherBox;
    local Actor A;
    if (H.Base != Level || H.Region.Zone == None || H.Region.Zone.bKillZone
        || H.Region.Zone.bPainZone || H.Region.Zone.bWaterZone || H.DrawScale <= 0)
        return False;
    Extent.X = H.CollisionRadius; Extent.Y = H.CollisionRadius; Extent.Z = H.CollisionHeight;
    FinishPoint = H.Location + Forward * 96 + vect(0,0,1) * (96 * H.DrawScale);
    if (H.Trace(HitLocation, HitNormal, FinishPoint, H.Location + vect(0,0,2), True, Extent) != None)
        return False;
    if (H.Trace(HitLocation, HitNormal, H.Location + vect(0,0,1) * (96 * H.DrawScale),
        H.Location + vect(0,0,2), True, Extent) != None) return False;
    if (!H.CanFit(H.CollisionRadius, H.CollisionHeight, H.CollisionWidth, FinishPoint, H.Rotation))
        return False;
    Corridor = H.GetWorldCollisionBox();
    if (Corridor.IsValid == 0) return False;
    Corridor.Min.X = FMin(Corridor.Min.X, Corridor.Min.X + Forward.X * 96) - 2;
    Corridor.Max.X = FMax(Corridor.Max.X, Corridor.Max.X + Forward.X * 96) + 2;
    Corridor.Min.Y = FMin(Corridor.Min.Y, Corridor.Min.Y + Forward.Y * 96) - 2;
    Corridor.Max.Y = FMax(Corridor.Max.Y, Corridor.Max.Y + Forward.Y * 96) + 2;
    Corridor.Max.Z += 96 * H.DrawScale + 2;
    foreach AllActors(Class'Actor', A)
        if (A != H && A != Level && A != self && A.bCollideActors && !CoopGame.IsSpentCoopScene(A))
        {
            OtherBox = A.GetWorldCollisionBox();
            if (OtherBox.IsValid == 0) return False;
            if (OtherBox.Min.X < Corridor.Max.X && OtherBox.Max.X > Corridor.Min.X
                && OtherBox.Min.Y < Corridor.Max.Y && OtherBox.Max.Y > Corridor.Min.Y
                && OtherBox.Min.Z < Corridor.Max.Z && OtherBox.Max.Z > Corridor.Min.Z)
                return False;
        }
    return True;
}

event Timer()
{
    local rotator Facing;
    local vector Forward;
    local byte I;
    if (bFinished) return;
    if (Level.TimeSeconds > Deadline) { Finish("BLOCKED", "timeout"); return; }
    if (CoopGame.bStoryCaptured) { bSawCapture = True; return; }
    if (CoopGame.bCoopRecoveryBlocked
        || (CoopGame.IntroCoordinator != None
            && CoopGame.IntroCoordinator.Phase == 6))
    { Finish("BLOCKED", "intro-terminal-failure"); return; }
    if (!bSawCapture || !ReadyPair() || Level.Pauser != "") return;
    if (CoopGame.IntroCoordinator == None || CoopGame.IntroCoordinator.Phase != 5)
        return;
    if (ReleasedAt < 0) ReleasedAt = Level.TimeSeconds;
    if (Level.TimeSeconds < ReleasedAt + 1) return;
    if (!bObserveSent)
    {
        Subject = Witnesses[0];
        RootBone = Subject.BoneName(0);
        PelvisBone = 'bip01 pelvis'; FootBone = 'bip01 l foot';
        if (Subject.Mesh == None || RootBone == '' || Subject.BoneNumber(RootBone) < 0
            || Subject.BoneNumber(PelvisBone) < 0 || Subject.BoneNumber(FootBone) < 0)
        { Finish("BLOCKED", "authority-bone-names-not-valid"); return; }
        bObserveSent = True;
        Deadline = Level.TimeSeconds + 15;
        for (I = 0; I < 2; I++)
            Witnesses[I].ClientMountObserve(Serial, Subject, CoopGame.RuntimeProbe ~= "MountRootB1");
        return;
    }
    if (!bStarted)
    {
        if (bWitnessReady[0] == 0 || bWitnessReady[1] == 0) return;
        if (bWitnessBones[0] == 0 || bWitnessBones[1] == 0)
        { Finish("BLOCKED", "client-bone-context"); return; }
        Facing.Yaw = Subject.Rotation.Yaw;
        Forward = vector(Facing);
        if (!ClearExistingVolume(Subject, Forward))
        { Finish("BLOCKED", "existing-volume-no-relocation"); return; }
        if (!Subject.PrepareMountTrial(self, Serial, Forward * 30 + vect(0,0,1) * (32 * Subject.DrawScale)))
        { Finish("BLOCKED", "prepare-preconditions"); return; }
        bStarted = True;
        Deadline = Level.TimeSeconds + 25;
        return;
    }
    if (Subject.bTrialFailed) { Finish("BLOCKED", Subject.TrialFailure); return; }
    if (Subject.bTrialActive) return;
    if (Subject.TrialMountingCount != 1 || Subject.TrialShrinkCount != 1
        || Subject.TrialRestoreCount != 1 || Subject.TrialDuplicateResiduals != 0
        || Subject.TrialResidualCount == 0 || !Subject.bTrialSawFrameChange
        || Subject.TrialSnapshot == None || Subject.TrialSnapshot.bActive
        || !Subject.IsInState('PlayerWalking')
        || (Subject.Physics != PHYS_Walking && Subject.Physics != PHYS_Falling))
    { Finish("FAIL", "original-state-observation-contract"); return; }
    // No transformed-distance-based PASS. Client samples + visible recording
    // and (for cache/root-consume claims) native trace must be reviewed separately.
    Finish("OBSERVED_ORIGINAL_FLOW", "original-states-capsule-resume-observed-finalPhysics="
        $ Subject.Physics $ "-root-and-render-unverified");
}

event Tick(float DeltaTime)
{
    if (bFinished || Subject == None || !Subject.bTrialActive
        || Level.TimeSeconds < NextAuthoritySample) return;
    NextAuthoritySample = Level.TimeSeconds + 0.03333333;
    Log("[MP_MOUNT_SERVER_POSE] time=" $ Level.TimeSeconds $ " loc=" $ Subject.Location
        $ " role=" $ Subject.Role $ " remote=" $ Subject.RemoteRole $ " phys=" $ Subject.Physics
        $ " state=" $ Subject.GetStateName() $ " rot=" $ Subject.Rotation $ " seq=" $ Subject.AnimSequence
        $ " frame=" $ Subject.AnimFrame $ " rate=" $ Subject.AnimRate
        $ " move=" $ Subject.bAnimMove $ " pivot=" $ Subject.PrePivot
        $ " capsule=" $ Subject.CollisionRadius $ "," $ Subject.CollisionHeight $ "," $ Subject.CollisionWidth);
    // Do not evaluate authority bones here: ApplyAnim may mutate the very root
    // cache whose native consumption is under test. Client-only BonePos reads
    // cannot take the Role4 actor-root-move branch. Native trace is a separate
    // optional experiment, not a scripted drain of GetRootMovement.
}

defaultproperties
{
    RemoteRole=ROLE_None
    bHidden=True
    DrawType=DT_None
    bCollideActors=False
    bCollideWorld=False
    bBlockActors=False
    bBlockPlayers=False
}
