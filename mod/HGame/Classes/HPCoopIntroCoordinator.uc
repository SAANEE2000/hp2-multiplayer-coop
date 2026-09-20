// REVIEW ONLY. Opt-in, first fresh Ch1 intro; not a campaign recovery system.
class HPCoopIntroCoordinator extends Actor;

var HPCoopGame Game;
var CutScene Scene;
var HPCoopHarry Members[2];
var byte Ready[2];
// 0 unused, 1 prepare, 2 original captures / role handoff, 3 running,
// 4 release handshake, 5 completed, 6 terminal blocked.
var byte Phase;
var bool bPermit, bLeaderRoleSeen, bTimeoutReported;
var float Deadline, WalkDeadline;
var string FailureReason;

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
    Phase = 6;
    bPermit = False;
    Deadline = Level.TimeSeconds + 20;
    Game.bCoopRecoveryBlocked = True;
    // This is terminal for this loaded world. Never ForceFinish, emit a cue,
    // BeginChallenge again, adopt a new canonical, or claim a rollback.
    if (Game.StoryView != None) Game.StoryView.SetCoopCapture(False, None, None);
    for (I = 0; I < 2; I++)
        if (Members[I] != None && !Members[I].bDeleteMe)
            Members[I].AbortCoopIntro(Reason);
    Log("[MP_INTRO] BLOCKED reason=" $ Reason $ " scene=" $ Scene
        $ " played=" $ Scene.nPlayedCount $ " recovery=fresh-host-required");
}

event Tick(float DeltaTime)
{
    local byte I;
    if (Role != ROLE_Authority || Phase == 0 || Phase == 5) return;
    if (Phase == 6)
    {
        if (!bTimeoutReported && Level.TimeSeconds > Deadline)
        {
            bTimeoutReported = True;
            Log("[MP_INTRO] failed-session-retained; no automatic recovery or progression");
        }
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
