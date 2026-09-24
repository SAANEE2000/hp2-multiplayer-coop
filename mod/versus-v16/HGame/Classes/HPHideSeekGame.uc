// Hide & Seek reuses the complete accepted Versus login, slot, character,
// movement, camera, animation and spell transport pipeline.
class HPHideSeekGame extends HPVersusGame;

var float HideDuration;
var float HuntDuration;
var float RoundOverDuration;
var byte PreviousHunterSlot;
var HPVersusHarry HunterPawn;
var HPHideSeekHunterWaitStart HunterWaitStart;
var HPHideSeekHunterSeekStart HunterSeekStart;
var HPHideSeekArena HideSeekArena;
var bool bHideSeekProbe;
var bool bHideSeekProbeComplete;
var byte HideSeekProbeStage;
var float HideSeekProbeNextTime;
var byte HideSeekProbeFirstHunterSlot;

function InitGame(string Options, out string Error)
{
    local string InOpt;

    Super.InitGame(Options, Error);
    InOpt = ParseOption(Options, "HideTime");
    if (InOpt != "")
        HideDuration = FClamp(float(InOpt), 5.0, 600.0);
    InOpt = ParseOption(Options, "HuntTime");
    if (InOpt != "")
        HuntDuration = FClamp(float(InOpt), 15.0, 1200.0);
    bHideSeekProbe = ParseOption(Options, "HideSeekProbe") ~= "1";
    Log("HPHideSeekGame loaded hide=" $ string(HideDuration)
        $ " hunt=" $ string(HuntDuration)
        $ " probe=" $ string(bHideSeekProbe));
}

// Hide & Seek has no FFA pickups or interaction-spell fixture.
function SpawnVersusPickups() {}
function ResetVersusPickups() {}
function SpawnVersusInteractionArena() {}

event PostBeginPlay()
{
    Super.PostBeginPlay();
    PreviousHunterSlot = 255;
    SpawnHideSeekArena();
    CacheHideSeekStarts();
    EnterHideSeekWaiting();
}

function bool IsHideSeekFixtureMap()
{
    return InStr(Caps(string(Level)), "HPV_HIDESEEK") >= 0;
}

function SpawnHideSeekArena()
{
    if (Role != ROLE_Authority || !IsHideSeekFixtureMap())
        return;
    HideSeekArena = Spawn(Class'HPHideSeekArena',,,
        GetVersusPickupCenter(), rot(0,0,0));
}

function CacheHideSeekStarts()
{
    local HPHideSeekHunterWaitStart W;
    local HPHideSeekHunterSeekStart S;

    HunterWaitStart = None;
    HunterSeekStart = None;
    foreach AllActors(Class'HPHideSeekHunterWaitStart', W)
        if (HunterWaitStart == None)
            HunterWaitStart = W;
    foreach AllActors(Class'HPHideSeekHunterSeekStart', S)
        if (HunterSeekStart == None)
            HunterSeekStart = S;

    Log("HPHideSeek starts wait=" $ string(HunterWaitStart)
        $ " seek=" $ string(HunterSeekStart));
}

function InitGameReplicationInfo()
{
    Super.InitGameReplicationInfo();
    UpdateVersusGRI();
}

function bool GetHideSeekProbePlayers(out HPVersusHarry HiderA,
    out HPVersusHarry HiderB)
{
    local HPVersusHarry H;

    foreach AllActors(Class'HPVersusHarry', H)
        if (H.Player != None && H != HunterPawn && H.HideSeekRole == 2)
        {
            if (HiderA == None)
                HiderA = H;
            else if (HiderB == None)
            {
                HiderB = H;
                return True;
            }
        }
    return False;
}

function HideSeekProbeResult(bool bPassed, string CheckName)
{
    if (bPassed)
        Log("HPHideSeekProbe PASS check=" $ CheckName);
    else
        Log("HPHideSeekProbe FAIL check=" $ CheckName);
}

function RunHideSeekProbe()
{
    local HPVersusHarry A;
    local HPVersusHarry B;
    local HPVersusHarry H;
    local HPVersusPRI APRI;
    local bool bProfilesOkay;

    if (!bHideSeekProbe || bHideSeekProbeComplete
        || Level.TimeSeconds < HideSeekProbeNextTime)
        return;

    if (HideSeekProbeStage == 0)
    {
        if (VersusPhase != 'HidePhase' || !GetHideSeekProbePlayers(A, B))
            return;
        HideSeekProbeFirstHunterSlot = HunterPawn.VersusSlot;
        HideSeekProbeResult(CountVersusPlayers() >= 3
            && HunterPawn.HideSeekRole == 1 && CountHidersLeft() == 2,
            "three-clients-and-role-selection");
        HideSeekProbeResult(HunterWaitStart != None
            && HunterSeekStart != None && HideSeekArena != None
            && HideSeekArena.bArenaReady,
            "functional-map-markers");
        A.ApplyHideSeekDisguise(1);
        HideSeekProbeResult(A.HideSeekDisguiseIndex == 1
            && A.Mesh == class'HPHideSeekDisguiseCatalog'.static.GetMesh(1),
            "server-authoritative-disguise");
        PhaseEndTime = Level.TimeSeconds;
        HideSeekProbeStage = 1;
        HideSeekProbeNextTime = Level.TimeSeconds + 0.25;
        return;
    }

    if (HideSeekProbeStage == 1)
    {
        if (VersusPhase != 'HuntPhase' || !GetHideSeekProbePlayers(A, B))
            return;
        HideSeekProbeResult(!HunterPawn.bVersusModeMovementLocked
            && !HunterPawn.bVersusModeCastingLocked
            && HunterPawn.SelectedVersusSpell == 0,
            "hunter-seek-unlock-rictusempra-only");
        NotifyHiderCaught(A, HunterPawn);
        HideSeekProbeResult(A.bHideSeekCaught && CountHidersLeft() == 1
            && VersusPhase == 'HuntPhase',
            "first-hider-caught-without-ffa-death");
        HideSeekProbeStage = 2;
        HideSeekProbeNextTime = Level.TimeSeconds + 0.25;
        return;
    }

    if (HideSeekProbeStage == 2)
    {
        if (VersusPhase != 'HuntPhase' || !GetHideSeekProbePlayers(A, B))
            return;
        if (A.bHideSeekCaught)
            NotifyHiderCaught(B, HunterPawn);
        else
            NotifyHiderCaught(A, HunterPawn);
        HideSeekProbeResult(CountHidersLeft() == 0
            && VersusPhase == 'RoundOver',
            "last-hider-ends-round");
        PhaseEndTime = Level.TimeSeconds + 0.25;
        HideSeekProbeStage = 3;
        HideSeekProbeNextTime = Level.TimeSeconds + 0.25;
        return;
    }

    if (HideSeekProbeStage == 3)
    {
        if (VersusPhase == 'NextRound')
            PhaseEndTime = Level.TimeSeconds;
        if (VersusPhase != 'HidePhase')
            return;
        HideSeekProbeResult(HunterPawn.VersusSlot
            != HideSeekProbeFirstHunterSlot,
            "next-round-rotates-hunter");
        bProfilesOkay = True;
        foreach AllActors(Class'HPVersusHarry', H)
            if (H.Player != None)
            {
                APRI = HPVersusPRI(H.PlayerReplicationInfo);
                if (APRI == None
                    || H.Mesh != class'HPVersusCharacterProfiles'.static.GetMesh(
                        APRI.SelectedCharacter))
                    bProfilesOkay = False;
            }
        HideSeekProbeResult(bProfilesOkay,
            "character-profile-survives-next-round");
        bHideSeekProbeComplete = True;
        Log("HPHideSeekProbe COMPLETE");
    }
}

function UpdateVersusGRI()
{
    local HPHideSeekGRI G;

    G = HPHideSeekGRI(GameReplicationInfo);
    if (G == None)
        return;
    G.HideSeekPhase = VersusPhase;
    G.MatchState = VersusPhase;
    G.bIsWarmup = VersusPhase == 'WaitingForPlayers'
        || VersusPhase == 'SelectHunter' || VersusPhase == 'HidePhase';
    G.bIsRoundActive = VersusPhase == 'HidePhase'
        || VersusPhase == 'HuntPhase';
    G.bMatchOver = VersusPhase == 'RoundOver';
    G.HidersLeft = CountHidersLeft();
    if (HunterPawn != None)
    {
        G.HunterSlot = HunterPawn.VersusSlot;
        if (HunterPawn.PlayerReplicationInfo != None)
            G.HunterName = HunterPawn.PlayerReplicationInfo.PlayerName;
    }
    else
    {
        G.HunterSlot = 255;
        G.HunterName = "";
    }
    if (PhaseEndTime > Level.TimeSeconds)
        G.RoundTimer = int(PhaseEndTime - Level.TimeSeconds + 0.99);
    else
        G.RoundTimer = 0;
}

event PostLogin(PlayerPawn NewPlayer)
{
    local HPVersusHarry H;

    Super.PostLogin(NewPlayer);
    H = HPVersusHarry(NewPlayer);
    if (H == None)
        return;

    // A late joiner waits safely for NextRound. Initial players remain ordinary
    // HPVersusHarry pawns until the state machine assigns their roles.
    if (VersusPhase == 'HidePhase' || VersusPhase == 'HuntPhase'
        || VersusPhase == 'RoundOver')
        H.SetHideSeekModeState(2, True, True, True);
    else
        H.SetHideSeekModeState(0, False, False, True);
    SyncHideSeekVisualsTo(H);
    UpdateVersusGRI();
}

function SyncHideSeekVisualsTo(HPVersusHarry Observer)
{
    local HPVersusHarry Target;

    if (Observer == None)
        return;
    foreach AllActors(Class'HPVersusHarry', Target)
        Observer.ClientObserveHideSeekVisual(Target,
            Target.HideSeekDisguiseIndex, Target.bHideSeekCaught);
}

function Timer()
{
    MaintainHideSeekPlayers();

    if (CountVersusPlayers() < 2)
    {
        if (VersusPhase != 'WaitingForPlayers')
            EnterHideSeekWaiting();
        UpdateVersusGRI();
        return;
    }

    if (VersusPhase == 'WaitingForPlayers')
        BeginSelectHunter();
    else if (VersusPhase == 'SelectHunter'
        && Level.TimeSeconds >= PhaseEndTime)
        BeginHidePhase();
    else if (VersusPhase == 'HidePhase'
        && Level.TimeSeconds >= PhaseEndTime)
        BeginHuntPhase();
    else if (VersusPhase == 'HuntPhase')
    {
        if (HunterPawn == None || HunterPawn.Player == None)
            EndHideSeekRound(False);
        else if (CountHidersLeft() <= 0)
            EndHideSeekRound(True);
        else if (Level.TimeSeconds >= PhaseEndTime)
            EndHideSeekRound(False);
    }
    else if (VersusPhase == 'RoundOver'
        && Level.TimeSeconds >= PhaseEndTime)
        BeginNextRound();
    else if (VersusPhase == 'NextRound'
        && Level.TimeSeconds >= PhaseEndTime)
        BeginSelectHunter();

    UpdateVersusGRI();
    RunHideSeekProbe();
}

function MaintainHideSeekPlayers()
{
    local Pawn P;
    local HPVersusHarry H;

    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        H = HPVersusHarry(P);
        if (H == None)
            continue;
        if (H.VersusSpeedBoostEndTime > 0.0
            && Level.TimeSeconds >= H.VersusSpeedBoostEndTime)
            H.ClearVersusSpeedBoost("HideSeekTimerExpired");
        if (H.VersusSpellLockEndTime > 0.0
            && Level.TimeSeconds >= H.VersusSpellLockEndTime)
            H.VersusSpellLockEndTime = 0.0;
        if (H.VersusDisarmEndTime > 0.0
            && Level.TimeSeconds >= H.VersusDisarmEndTime)
            H.VersusDisarmEndTime = 0.0;
    }
}

function EnterHideSeekWaiting()
{
    local HPVersusHarry H;

    bMatchInProgress = False;
    VersusPhase = 'WaitingForPlayers';
    PhaseEndTime = 0.0;
    HunterPawn = None;
    foreach AllActors(Class'HPVersusHarry', H)
        if (H.Player != None)
        {
            H.ClearHideSeekDisguise();
            H.SetHideSeekModeState(0, False, False, True);
        }
    Log("HPHideSeek phase=WaitingForPlayers players="
        $ string(CountVersusPlayers()));
}

function BeginSelectHunter()
{
    bMatchInProgress = False;
    VersusPhase = 'SelectHunter';
    PhaseEndTime = Level.TimeSeconds + 0.25;
    HunterPawn = ChooseHideSeekHunter();
    Log("HPHideSeek phase=SelectHunter hunter=" $ string(HunterPawn));
}

function HPVersusHarry ChooseHideSeekHunter()
{
    local HPVersusHarry H;
    local HPVersusHarry Pick;
    local int CandidateCount;
    local int PickIndex;

    foreach AllActors(Class'HPVersusHarry', H)
        if (H.Player != None && H.bVersusRegistered
            && (CountVersusPlayers() <= 1
                || H.VersusSlot != PreviousHunterSlot))
            CandidateCount++;
    if (CandidateCount == 0)
        return None;

    PickIndex = Rand(CandidateCount);
    CandidateCount = 0;
    foreach AllActors(Class'HPVersusHarry', H)
        if (H.Player != None && H.bVersusRegistered
            && (CountVersusPlayers() <= 1
                || H.VersusSlot != PreviousHunterSlot))
        {
            if (CandidateCount == PickIndex)
            {
                Pick = H;
                break;
            }
            CandidateCount++;
        }
    if (Pick != None)
        PreviousHunterSlot = Pick.VersusSlot;
    return Pick;
}

function NavigationPoint FindHideSeekHiderStart(byte WantedIndex)
{
    local HPHideSeekHiderStart S;
    local HPHideSeekHiderStart Fallback;

    foreach AllActors(Class'HPHideSeekHiderStart', S)
    {
        if (Fallback == None)
            Fallback = S;
        if (S.HiderIndex == WantedIndex)
            return S;
    }
    return Fallback;
}

function PlaceHideSeekPawn(HPVersusHarry H, NavigationPoint Destination)
{
    if (H == None || Destination == None)
        return;
    H.SetLocation(Destination.Location);
    H.SetRotation(Destination.Rotation);
    H.DesiredRotation = Destination.Rotation;
    H.ViewRotation = Destination.Rotation;
}

function BeginHidePhase()
{
    local HPVersusHarry H;
    local HPVersusPRI PRI;
    local byte HiderIndex;

    if (HunterPawn == None)
    {
        EnterHideSeekWaiting();
        return;
    }
    CacheHideSeekStarts();
    VersusPhase = 'HidePhase';
    PhaseEndTime = Level.TimeSeconds + HideDuration;
    bMatchInProgress = False;

    foreach AllActors(Class'HPVersusHarry', H)
    {
        if (H.Player == None || !H.bVersusRegistered)
            continue;
        PRI = HPVersusPRI(H.PlayerReplicationInfo);
        H.PrepareHideSeekRound();
        if (PRI != None)
            H.ApplyCharacterSkin(PRI.SelectedCharacter);
        if (H == HunterPawn)
        {
            H.ServerSelectVersusSpell(0);
            H.SetHideSeekModeState(1, False, True, True);
            PlaceHideSeekPawn(H, HunterWaitStart);
        }
        else
        {
            H.SetHideSeekModeState(2, False, False, True);
            PlaceHideSeekPawn(H, FindHideSeekHiderStart(HiderIndex));
            HiderIndex++;
        }
    }
    if (HunterPawn.PlayerReplicationInfo != None)
        BroadcastMessage(HunterPawn.PlayerReplicationInfo.PlayerName
            $ " is the Hunter. Hide!");
    Log("HPHideSeek phase=HidePhase hunter=" $ string(HunterPawn)
        $ " hiders=" $ string(CountHidersLeft()));
}

function BeginHuntPhase()
{
    local HPVersusHarry H;

    if (HunterPawn == None)
    {
        EndHideSeekRound(False);
        return;
    }
    VersusPhase = 'HuntPhase';
    PhaseEndTime = Level.TimeSeconds + HuntDuration;
    bMatchInProgress = True;
    PlaceHideSeekPawn(HunterPawn, HunterSeekStart);
    HunterPawn.ServerSelectVersusSpell(0);
    HunterPawn.SetHideSeekModeState(1, False, False, False);
    foreach AllActors(Class'HPVersusHarry', H)
        if (H != HunterPawn && H.Player != None && !H.bHideSeekCaught)
            H.SetHideSeekModeState(2, False, False, True);
    BroadcastMessage("The hunt begins!");
    Log("HPHideSeek phase=HuntPhase hiders="
        $ string(CountHidersLeft()));
}

function bool IsVersusCastAllowed(HPVersusHarry H, byte SpellSlot)
{
    return VersusPhase == 'HuntPhase' && H == HunterPawn
        && H != None && H.HideSeekRole == 1 && !H.bHideSeekCaught
        && SpellSlot == 0;
}

function bool IsVersusDamageAllowed(
    HPVersusHarry Victim, Pawn Attacker, name DamageType)
{
    return False;
}

function bool HandleVersusRictusempraModeHit(
    HPVersusHarry Victim, Pawn Attacker)
{
    // Consume every player hit in this mode so FFA HP/death/frag semantics
    // never leak into Hide & Seek.
    if (VersusPhase == 'HuntPhase' && Attacker == HunterPawn
        && Victim != None && Victim.HideSeekRole == 2
        && !Victim.bHideSeekCaught)
        NotifyHiderCaught(Victim, Attacker);
    return True;
}

function bool CanVersusDisguise(HPVersusHarry H)
{
    return H != None && H.HideSeekRole == 2 && !H.bHideSeekCaught
        && (VersusPhase == 'HidePhase' || VersusPhase == 'HuntPhase');
}

function NotifyHiderCaught(HPVersusHarry Hider, Pawn Catcher)
{
    if (Role != ROLE_Authority || Hider == None
        || Hider.bHideSeekCaught || Hider.HideSeekRole != 2
        || Catcher != HunterPawn || VersusPhase != 'HuntPhase')
        return;

    Hider.ClearHideSeekDisguise();
    Hider.SetHideSeekModeState(2, True, True, True);
    if (Hider.PlayerReplicationInfo != None)
        BroadcastMessage(Hider.PlayerReplicationInfo.PlayerName
            $ " was found!");
    UpdateVersusGRI();
    if (CountHidersLeft() <= 0)
        EndHideSeekRound(True);
}

function int CountHidersLeft()
{
    local HPVersusHarry H;
    local int Count;

    foreach AllActors(Class'HPVersusHarry', H)
        if (H.Player != None && H.bVersusRegistered
            && H.HideSeekRole == 2 && !H.bHideSeekCaught)
            Count++;
    return Count;
}

function EndHideSeekRound(bool bHunterWon)
{
    local HPVersusHarry H;
    local HPHideSeekGRI G;

    if (VersusPhase == 'RoundOver')
        return;
    bMatchInProgress = False;
    VersusPhase = 'RoundOver';
    PhaseEndTime = Level.TimeSeconds + RoundOverDuration;
    foreach AllActors(Class'HPVersusHarry', H)
        if (H.Player != None)
            H.SetHideSeekModeState(H.HideSeekRole,
                H.bHideSeekCaught, True, True);
    G = HPHideSeekGRI(GameReplicationInfo);
    if (bHunterWon)
    {
        BroadcastMessage("Hunter wins!");
        if (G != None && HunterPawn != None
            && HunterPawn.PlayerReplicationInfo != None)
            G.WinnerName = HunterPawn.PlayerReplicationInfo.PlayerName;
    }
    else
    {
        BroadcastMessage("Hiders win!");
        if (G != None)
            G.WinnerName = "HIDERS";
    }
    Log("HPHideSeek phase=RoundOver hunterWon=" $ string(bHunterWon));
}

function BeginNextRound()
{
    local HPVersusHarry H;
    local HPVersusPRI PRI;

    VersusPhase = 'NextRound';
    PhaseEndTime = Level.TimeSeconds + 1.0;
    HunterPawn = None;
    foreach AllActors(Class'HPVersusHarry', H)
        if (H.Player != None)
        {
            H.PrepareHideSeekRound();
            PRI = HPVersusPRI(H.PlayerReplicationInfo);
            if (PRI != None)
                H.ApplyCharacterSkin(PRI.SelectedCharacter);
            H.SetHideSeekModeState(0, False, True, True);
        }
    Log("HPHideSeek phase=NextRound");
}

defaultproperties
{
    GameName="Harry Potter Hide and Seek"
    HideDuration=60.0
    HuntDuration=180.0
    RoundOverDuration=6.0
    PreviousHunterSlot=255
    DefaultPlayerClass=Class'HGame.HPVersusHarry'
    GameReplicationInfoClass=Class'HGame.HPHideSeekGRI'
    MaxPlayers=8
    bDeathMatch=True
}
