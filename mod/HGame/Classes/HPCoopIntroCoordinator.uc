// REVIEW ONLY. Opt-in, first fresh Ch1 intro; not a campaign recovery system.
class HPCoopIntroCoordinator extends Actor;

var HPCoopGame Game;
var CutScene Scene;
var HPCoopHarry Members[2];
var byte Ready[2];
// 1 awaiting ACK, 2 ACK on time, 3 unavailable/disconnected, 4 deadline missed,
// 5 ACK after deadline. Late evidence never erases the missed deadline.
var byte CleanupState[2];
var int CleanupSerial[2];
// 0 unused, 1 prepare, 2 original captures / role handoff, 3 running,
// 4 release handshake, 5 completed, 6 terminal blocked.
var byte Phase;
var bool bPermit, bLeaderRoleSeen, bTimeoutReported;
var float Deadline, WalkDeadline;
var string FailureReason;
var bool bFaultDropLogged, bFaultDuplicateDone, bFaultDeathDone, bFaultSnapshotLogged;
var float FaultSnapshotAfter;

function bool IsActive()
{
    return Phase > 0 && Phase < 5;
}

function bool IsMember(HPCoopHarry H)
{
    return H != None && (H == Members[0] || H == Members[1]);
}

function bool RosterValid()
{
    return Game != None && Members[0] != None && Members[1] != None
        && Game.CoopPlayers[0] == Members[0] && Game.CoopPlayers[1] == Members[1]
        && Game.StoryLeader == Members[0]
        && Game.IsAliveCoopPlayer(Members[0]) && Game.IsAliveCoopPlayer(Members[1]);
}

function bool AllowPlay(CutScene Candidate)
{
    local byte I;
    if (Game == None || Role != ROLE_Authority) return False;
    if (Phase == 6) return False;
    if (Phase == 2 && bPermit && Candidate == Scene)
    {
        bPermit = False;
        return True;
    }
    if (!(Candidate.FileName ~= "Ch1RictuIntro"))
    {
        if (IsActive())
        {
            Fail("overlapping-scene");
            return False;
        }
        return True;
    }
    // Duplicate requests never replay, reset counters, or consume another permit.
    if (Phase != 0) return False;
    Scene = Candidate;
    Members[0] = Game.CoopPlayers[0];
    Members[1] = Game.CoopPlayers[1];
    if (!(string(Level.Outer.Name) ~= "Ch1Rictusempra")
        || Candidate.Class != Class'CutScene' || !Candidate.bPlayOnce
        || !Candidate.bLevelLoadStarts || Candidate.nPlayedCount != 0
        || Candidate.bPlaying || Game.RequiredPlayers != 2
        || Game.bWaitingForPlayers || Game.bStoryCaptured || Game.bCoopCapturedAuthorityUsed
        || Game.ReadyPlayers[0] == 0 || Game.ReadyPlayers[1] == 0
        || !RosterValid() || Game.StoryView == None
        || Game.StoryLeader.Cam == None
        || !Game.StoryLeader.CutQuestion("ChallengeIsFirstTime"))
    {
        Fail("initial-preflight-contract");
        return False;
    }
    for (I = 0; I < 2; I++)
        if (Members[I].RemoteRole != ROLE_AutonomousProxy
            || !Members[I].IsInState('PlayerWalking')
            || Members[I].bCoopAwaitResume || Members[I].bCoopSceneMode
            || Members[I].CutNotifyActor != None)
        {
            Fail("participant-not-free");
            return False;
        }
    Phase = 1;
    Deadline = Level.TimeSeconds + 20;
    // Fast-forward calls CutBypass and synthetic timer completions. This first
    // intro contract requires the real walk; parent FastForward will refuse.
    Scene.bSkipAllowed = False;
    for (I = 0; I < 2; I++) Members[I].bCoopIntroInputHold = True;
    // Presentation/input hold only. Original actor captures, command threads and
    // nPlayedCount have not run. The original Play call returns below.
    Game.SetStoryCaptured(True);
    Log("[MP_INTRO] preflight scene=" $ Scene $ " deadline=" $ Deadline);
    return False;
}

function bool CanAcceptCapture(HPCoopHarry H)
{
    if (Phase != 1 || !RosterValid()) return False;
    return (Members[0] == H && Ready[0] == 0) || (Members[1] == H && Ready[1] == 0);
}

function Captured(HPCoopHarry H, int Serial)
{
    local byte I;
    if (Phase != 1 || !RosterValid() || Serial != H.CoopSceneSerial) return;
    for (I = 0; I < 2; I++)
        if (Members[I] == H && Ready[I] == 0)
        {
            Ready[I] = 1;
            Log("[MP_INTRO] ready slot=" $ I $ " serial=" $ Serial);
            RunDuplicateFault(H, Serial);
        }
}

function SimulatedOwner(HPCoopHarry H, int Serial)
{
    if (Phase != 2 || !RosterValid() || H != Members[0]
        || H.RemoteRole != ROLE_SimulatedProxy || Serial != H.CoopSceneSerial) return;
    bLeaderRoleSeen = True;
}

function bool CanEnterAuthority(HPCoopHarry H)
{
    local CutScript C;
    if (Phase != 2 || !RosterValid() || H != Members[0]) return False;
    C = CutScript(H.CutNotifyActor);
    return C != None && C.parentCutScene == Scene && H.IsInState('stateCutIdle');
}

function bool AllowScript(CutScript C)
{
    if (C.parentCutScene != Scene) return Phase != 6 && !IsActive();
    if (Phase == 6) return False;
    if (!RosterValid()) { Fail("roster-changed"); return False; }
    if (Members[0].bCoopWalkBlocked) { Fail("original-walk-blocked"); return False; }
    // Thread0 retains all original captures and branch cues. Other threads wait
    // for the leader's real owner Role2 observation; no command is consumed.
    if (Phase == 2) return C.threadNum == 0;
    return Phase == 3 || Phase == 4;
}

function bool CanRelease()
{
    return Phase == 3 && RosterValid() && Members[0].bCoopWalkIssued
        && Members[0].bCoopWalkReached && Members[0].bCoopWalkCueReceived
        && !Members[0].bCoopWalkBlocked;
}

function bool BeginRelease()
{
    if (!CanRelease())
    {
        Fail("release-before-verified-walk");
        return False;
    }
    Phase = 4;
    Deadline = Level.TimeSeconds + 15;
    return True;
}

function Fail(string Reason)
{
    local byte I;
    if (Phase == 6 || Phase == 5) return;
    FailureReason = Reason;
    FaultSnapshotAfter = Level.TimeSeconds + 0.25;
    Phase = 6;
    bPermit = False;
    Deadline = Level.TimeSeconds + 20;
    Game.bCoopRecoveryBlocked = True;
    // This is terminal for this loaded world. Never ForceFinish, emit a cue,
    // BeginChallenge again, adopt a new canonical, or claim a rollback.
    if (Game.StoryView != None) Game.StoryView.SetCoopCapture(False, None, None);
    for (I = 0; I < 2; I++)
    {
        CleanupState[I] = 3;
        if (Members[I] != None && !Members[I].bDeleteMe
            && Game.CoopPlayers[I] == Members[I])
        {
            CleanupSerial[I] = Members[I].CoopSceneSerial + 1;
            if (Members[I].Player != None) CleanupState[I] = 1;
            if (CleanupState[I] == 1)
                Log("[MP_INTRO] failure-cleanup-await slot=" $ I
                    $ " serial=" $ CleanupSerial[I] $ " deadline=" $ Deadline);
            Members[I].AbortCoopIntro(Reason);
        }
        if (CleanupState[I] == 3)
            Log("[MP_INTRO] failure-cleanup-unavailable slot=" $ I);
    }
    Log("[MP_INTRO] BLOCKED reason=" $ Reason $ " scene=" $ Scene
        $ " played=" $ Scene.nPlayedCount $ " recovery=fresh-host-required");
}

function FailureCleanupAck(HPCoopHarry H, int Serial)
{
    local byte I;
    local bool bLate;
    // Dead participants are eligible; this is cleanup, never a revive/resume ACK.
    if (Role != ROLE_Authority || Phase != 6 || Game == None || H == None
        || H.bDeleteMe || H.Level != Level || H.Player == None || Serial <= 0
        || H.RemoteRole != ROLE_AutonomousProxy || !H.bCoopIntroInputHold
        || H.bCoopSceneMode || H.bCoopSceneAwaitRelease) return;
    for (I = 0; I < 2; I++)
        if (Members[I] == H && Game.CoopPlayers[I] == H
            && Serial == CleanupSerial[I] && Serial == H.CoopSceneSerial
            && (CleanupState[I] == 1 || CleanupState[I] == 4))
        {
            bLate = Level.TimeSeconds > Deadline || CleanupState[I] == 4;
            if (bLate) CleanupState[I] = 5;
            else CleanupState[I] = 2;
            // A Role2 status RPC may have been absorbed. This fresh owner RPC
            // follows the owner's real Role3 observation, with unchanged health.
            H.PublishCoopStatus(True);
            Log("[MP_INTRO] failure-cleanup-ack slot=" $ I $ " serial=" $ Serial
                $ " late=" $ bLate $ " dead=" $ H.bCoopDead
                $ " status-revision=" $ H.CoopStatusRevision
                $ " time=" $ Level.TimeSeconds);
            CheckFailureCleanup();
            return;
        }
}

function CheckFailureCleanup()
{
    local byte I;
    local bool bPending;
    if (Role != ROLE_Authority || Phase != 6 || Game == None) return;
    for (I = 0; I < 2; I++)
        if (CleanupState[I] == 1)
        {
            if (Members[I] == None || Members[I].bDeleteMe
                || Game.CoopPlayers[I] != Members[I] || Members[I].Player == None)
            {
                CleanupState[I] = 3;
                Log("[MP_INTRO] failure-cleanup-disconnected slot=" $ I
                    $ " serial=" $ CleanupSerial[I]);
            }
            else if (Level.TimeSeconds > Deadline)
            {
                CleanupState[I] = 4;
                Log("[MP_INTRO] failure-cleanup-timeout slot=" $ I
                    $ " serial=" $ CleanupSerial[I]);
            }
            else bPending = True;
        }
    if (!bPending && !bTimeoutReported)
    {
        bTimeoutReported = True;
        Log("[MP_INTRO] failure-cleanup-settled slot0=" $ CleanupState[0]
            $ " slot1=" $ CleanupState[1] $ " session-remains-blocked=True");
    }
}

function int FaultThreadCount()
{
    local int I, Count;
    if (Scene == None) return 0;
    for (I = 0; I < 20; I++)
        if (Scene.aThreads[I] != None) Count++;
    return Count;
}

function bool ShouldDropCapture(HPCoopHarry H, int Serial)
{
    local bool bSelected;
    // Called only after the owning RPC's role, serial, roster and timestamp
    // validation. This drops an actual owner report, not its camera rendering.
    if (Phase != 1 || !CanAcceptCapture(H) || Serial != H.CoopSceneSerial) return False;
    bSelected = (Game.CoopIntroFault ~= "MissingAck0" && H == Members[0])
        || (Game.CoopIntroFault ~= "MissingAck1" && H == Members[1]);
    if (!bSelected) return False;
    if (!bFaultDropLogged)
    {
        bFaultDropLogged = True;
        Log("[MP_INTRO_FAULT] drop-valid-capture-ack mode=" $ Game.CoopIntroFault
            $ " pawn=" $ H $ " serial=" $ Serial $ " played=" $ Scene.nPlayedCount
            $ " threads=" $ FaultThreadCount());
    }
    return True;
}

function RunDuplicateFault(HPCoopHarry H, int Serial)
{
    local int PlayedBefore, ThreadsBefore, ReadyBefore;
    local float OwnerStampBefore, ServerStampBefore;
    local bool bSame;
    if (Phase != 1 || bFaultDuplicateDone || !(Game.CoopIntroFault ~= "DuplicateCallbacks")) return;
    bFaultDuplicateDone = True;
    PlayedBefore = Scene.nPlayedCount;
    ThreadsBefore = FaultThreadCount();
    ReadyBefore = Ready[0] + Ready[1];
    OwnerStampBefore = H.CoopSceneOwnerHoldStamp;
    ServerStampBefore = H.CoopSceneServerHoldTime;
    // Exercise the normal validation handler; never invoke Captured directly.
    H.ServerCoopSceneCaptured(Serial + 1, OwnerStampBefore);
    H.ServerCoopSceneCaptured(Serial, OwnerStampBefore);
    Scene.Play();
    bSame = Scene.nPlayedCount == PlayedBefore && FaultThreadCount() == ThreadsBefore
        && Ready[0] + Ready[1] == ReadyBefore
        && H.CoopSceneOwnerHoldStamp == OwnerStampBefore
        && H.CoopSceneServerHoldTime == ServerStampBefore;
    Log("[MP_INTRO_FAULT] duplicate-callbacks unchanged=" $ bSame
        $ " played=" $ Scene.nPlayedCount $ " threads=" $ FaultThreadCount()
        $ " ready=" $ (Ready[0] + Ready[1]) $ " serial=" $ Serial);
    if (!bSame) Fail("duplicate-callback-invariant");
}

function bool RunDeathFault()
{
    local HPCoopHarry Victim;
    if (Phase != 3 || bFaultDeathDone || !RosterValid()
        || !Members[0].IsInState('stateMovingToLoc')
        || !Members[0].bCoopWalkIssued || Members[0].bCoopWalkCueReceived
        || VSize2d(Members[0].Location - Members[0].CoopWalkStart) <= 1) return False;
    if (Game.CoopIntroFault ~= "DeathWalk0") Victim = Members[0];
    else if (Game.CoopIntroFault ~= "DeathWalk1") Victim = Members[1];
    else return False;
    bFaultDeathDone = True;
    Log("[MP_INTRO_FAULT] real-kill mode=" $ Game.CoopIntroFault $ " victim=" $ Victim
        $ " canonical-state=" $ Members[0].GetStateName()
        $ " moved-xy=" $ VSize2d(Members[0].Location - Members[0].CoopWalkStart));
    // Original co-op death callback must reach failure naturally. No direct Fail,
    // health assignment, synthetic cue, snap, movement or completion from this probe.
    Victim.KillHarry(True);
    return True;
}

function LogFaultFailureSnapshot()
{
    if (Game.CoopIntroFault == "" || Phase != 6 || bFaultSnapshotLogged
        || Level.TimeSeconds < FaultSnapshotAfter) return;
    bFaultSnapshotLogged = True;
    Log("[MP_INTRO_FAULT] late-failure-snapshot mode=" $ Game.CoopIntroFault
        $ " time=" $ Level.TimeSeconds $ " scene=" $ Scene
        $ " phase=" $ Phase $ " played=" $ Scene.nPlayedCount
        $ " threads=" $ FaultThreadCount() $ " playing=" $ Scene.bPlaying);
    if (Members[0] != None && !Members[0].bDeleteMe)
        Log("[MP_INTRO_FAULT] late-canonical notify=" $ Members[0].CutNotifyActor
            $ " capture-count=" $ Members[0].nPlayerCaptureCount
            $ " walk-issued=" $ Members[0].bCoopWalkIssued
            $ " state=" $ Members[0].GetStateName()
            $ " remote=" $ Members[0].RemoteRole);
}


event Tick(float DeltaTime)
{
    local byte I;
    if (Role != ROLE_Authority || Phase == 0 || Phase == 5) return;
    if (Phase == 6)
    {
        CheckFailureCleanup();
        LogFaultFailureSnapshot();
        return;
    }
    if (!RosterValid()) { Fail("roster-changed"); return; }
    if (Level.TimeSeconds > Deadline) { Fail("phase-timeout-" $ Phase); return; }
    if (Phase == 1 && Ready[0] != 0 && Ready[1] != 0)
    {
        Phase = 2;
        Deadline = Level.TimeSeconds + 10;
        bPermit = True;
        Scene.Play();
        if (bPermit || Scene.nPlayedCount != 1) Fail("play-permit-not-consumed");
    }
    else if (Phase == 2 && bLeaderRoleSeen)
    {
        Phase = 3;
        Deadline = Level.TimeSeconds + 120;
        Log("[MP_INTRO] running; both-ready and leader-role-observed");
    }
    else if (Phase == 3)
    {
        if (RunDeathFault()) return;
        if (Members[0].bCoopWalkBlocked) { Fail("original-walk-blocked"); return; }
        if (Members[0].bCoopWalkIssued && WalkDeadline == 0)
            WalkDeadline = Level.TimeSeconds + 12;
        if (WalkDeadline > 0 && !Members[0].bCoopWalkCueReceived
            && Level.TimeSeconds > WalkDeadline) Fail("original-walk-timeout");
    }
    else if (Phase == 4 && !Members[0].bCoopSceneMode && !Members[1].bCoopSceneMode
        && Scene.IsInState('Finished') && !Scene.bPlaying)
    {
        Phase = 5;
        for (I = 0; I < 2; I++)
        {
            Members[I].bCoopIntroInputHold = False;
            Members[I].ClientCoopIntroCompleted(Members[I].CoopSceneSerial);
        }
        Log("[MP_INTRO] complete; original scene finished and both resume barriers accepted");
    }
}

defaultproperties
{
    RemoteRole=ROLE_None
    bHidden=True
    Physics=PHYS_None
    bCollideActors=False
    bCollideWorld=False
}
