// Campaign session authority, deliberately independent of Versus match logic.
class HPCoopGame extends GameInfo;

var HPCoopHarry CoopPlayers[2];
var byte ReadyPlayers[2];
var HPCoopHarry StoryLeader;
var harry LegacyStoryHarry;
var byte PendingLoginSlot;
var bool bLoginInProgress;
var PlayerStart CompanionStart;
var string CanonicalCutName;
var int RequiredPlayers;
var bool bWaitingForPlayers;
var bool bStoryCaptured;
var HPCoopCutsceneView StoryView;
var HPCoopCampaignState CampaignState;
var string TestStage;
var string RuntimeProbe;
var bool bCoopRecoveryBlocked;
// Native captured movement is also required by a normal fresh Ch1 session.
var bool bCoopCapturedAuthorityDiagnostic, bCoopCapturedAuthorityUsed;
var bool bCoopFirstIntroPreflight;
var string CoopIntroFault;
var HPCoopIntroCoordinator IntroCoordinator;

event InitGame(string Options, out string Error)
{
    local harry MapHarry;
    local string CaptureMode, IntroMode, TravelSpells, TravelSource;
    Super.InitGame(Options, Error);
    TestStage = ParseOption(Options, "CoopTestStage");
    RuntimeProbe = ParseOption(Options, "CoopProbe");
    foreach AllActors(Class'harry', MapHarry)
        if (HPCoopHarry(MapHarry) == None && MapHarry.bIsPlayer)
        {
            LegacyStoryHarry = MapHarry;
            break;
        }
    // Level selection skips the preceding lesson. Supply its exact completed
    // state before native actor screening, but never overwrite carried state.
    if (TestStage == "" && RuntimeProbe == "" && LegacyStoryHarry != None
        && Level.NetMode == NM_DedicatedServer
        && (string(Level.Outer.Name) ~= "Ch1Rictusempra")
        && (LegacyStoryHarry.CurrentGameState == ""
            || (LegacyStoryHarry.CurrentGameState ~= "None")))
        TestStage = "RictusempraLessonComplete";
    CaptureMode = ParseOption(Options, "CoopCapturedAuthority");
    if (CaptureMode == "" && RuntimeProbe == ""
        && Level.NetMode == NM_DedicatedServer
        && (TestStage ~= "RictusempraLessonComplete"))
        CaptureMode = "1";
    if (CaptureMode != "" && CaptureMode != "0" && CaptureMode != "1")
    {
        Error = "CoopCapturedAuthority must be 0 or 1.";
        return;
    }
    bCoopCapturedAuthorityDiagnostic = CaptureMode == "1";
    if (bCoopCapturedAuthorityDiagnostic && (Level.NetMode != NM_DedicatedServer
        || !(TestStage ~= "RictusempraLessonComplete")
        || (RuntimeProbe != "" && !(RuntimeProbe ~= "AIInspect")
            && !(RuntimeProbe ~= "AICombat")
            && !(RuntimeProbe ~= "AICombatDeath")
            && !(RuntimeProbe ~= "AISnail")
            && !(RuntimeProbe ~= "Travel")
            && !(RuntimeProbe ~= "MountRootB0")
            && !(RuntimeProbe ~= "MountRootB1"))))
    {
        Error = "CoopCapturedAuthority requires dedicated Ch1 with no active probe.";
        return;
    }
    if (RuntimeProbe != "" && (!(RuntimeProbe ~= "Health") && !(RuntimeProbe ~= "Lumos") && !(RuntimeProbe ~= "Pickup") && !(RuntimeProbe ~= "PickupNet") && !(RuntimeProbe ~= "AIInspect") && !(RuntimeProbe ~= "AICombat") && !(RuntimeProbe ~= "AICombatDeath") && !(RuntimeProbe ~= "AISnail") && !(RuntimeProbe ~= "Travel") && !(RuntimeProbe ~= "MountRootB0") && !(RuntimeProbe ~= "MountRootB1")
        || !(TestStage ~= "RictusempraLessonComplete") || Level.NetMode != NM_DedicatedServer))
    {
        Error = "CoopProbe requires a dedicated Ch1 test fixture and a known probe.";
        return;
    }
    TravelSpells = ParseOption(Options, "CoopTravelSpells");
    TravelSource = ParseOption(Options, "CoopTravelSource");
    if (TravelSpells != "" || TravelSource != "")
    {
        if (!(TravelSource ~= "Ch1Rictusempra")
            || !(string(Level.Outer.Name) ~= "Entryhall_hub")
            || Level.NetMode != NM_DedicatedServer || TestStage != ""
            || RuntimeProbe != ""
            || !Class'HPCoopCampaignState'.static.SeedTravelState(
                LegacyStoryHarry, ParseOption(Options, "GameState"), TravelSpells))
        {
            Error = "Invalid co-op travel handoff.";
            return;
        }
    }
    if (TestStage != "")
    {
        if (!(TestStage ~= "RictusempraLessonComplete")
            || !Class'HPCoopCampaignState'.static.SeedCh1TestStage(LegacyStoryHarry))
        {
            Error = "CoopTestStage requires a fresh Ch1Rictusempra map with no imported campaign state.";
            return;
        }
    }
    IntroMode = ParseOption(Options, "CoopFirstIntroPreflight");
    if (IntroMode == "" && RuntimeProbe == ""
        && bCoopCapturedAuthorityDiagnostic
        && GetIntOption(Options, "RequiredPlayers", 2) == 2)
        IntroMode = "1";
    if (IntroMode != "" && IntroMode != "0" && IntroMode != "1")
    {
        Error = "CoopFirstIntroPreflight must be 0 or 1.";
        return;
    }
    bCoopFirstIntroPreflight = IntroMode == "1";
    CoopIntroFault = ParseOption(Options, "CoopIntroFault");
    if (CoopIntroFault != "" && (!(CoopIntroFault ~= "MissingAck0")
        && !(CoopIntroFault ~= "MissingAck1") && !(CoopIntroFault ~= "DuplicateCallbacks")
        && !(CoopIntroFault ~= "DeathWalk0") && !(CoopIntroFault ~= "DeathWalk1")))
    {
        Error = "Unknown CoopIntroFault mode.";
        return;
    }
    if (CoopIntroFault != "" && !bCoopFirstIntroPreflight)
    {
        Error = "CoopIntroFault requires explicit first-intro preflight.";
        return;
    }
    if (bCoopFirstIntroPreflight && (!bCoopCapturedAuthorityDiagnostic
        || GetIntOption(Options, "RequiredPlayers", 2) != 2))
    {
        Error = "CoopFirstIntroPreflight requires captured diagnostic and two players.";
        return;
    }
    if (((RuntimeProbe ~= "MountRootB0") || (RuntimeProbe ~= "MountRootB1")
        || (RuntimeProbe ~= "Travel"))
        && (!bCoopFirstIntroPreflight || CoopIntroFault != ""))
    {
        Error = "Movement/travel diagnostic requires the normal first-intro preflight.";
        return;
    }
    MaxPlayers = 2;
    RequiredPlayers = Clamp(GetIntOption(Options, "RequiredPlayers", 2), 1, 2);
    bWaitingForPlayers = True;
    Level.Pauser = "WaitingForCoopPlayers";
    Log("[MP_LOGIN] mode=coop build=foundation-1 maxPlayers=2");
}

event PostBeginPlay()
{
    local CutScene Scene;
    local HPCoopLumosProbe LumosProbe;
    local HPCoopPickupProbe PickupProbe;
    Super.PostBeginPlay();
    // Keep the original command/cue interpreters; dedicated servers have no
    // local Harry console for the legacy logging path.
    foreach AllActors(Class'CutScene', Scene)
    {
        if (Scene.FileName == "")
            Scene.CutscriptClass = Class'HPCoopCutScript';
        else
            Scene.CutscriptDiskClass = Class'HPCoopCutScriptDisk';
    }
    StoryView = Spawn(Class'HPCoopCutsceneView', self);
    if (bCoopFirstIntroPreflight)
    {
        IntroCoordinator = Spawn(Class'HPCoopIntroCoordinator', self);
        if (IntroCoordinator != None) IntroCoordinator.Game = self;
    }
    if (RuntimeProbe ~= "Health") Spawn(Class'HPCoopHealthProbe', self);
    if (RuntimeProbe ~= "Lumos")
    {
        LumosProbe = Spawn(Class'HPCoopLumosProbe', self);
        if (LumosProbe != None)
        {
            LumosProbe.bOptIn = True;
            if (!LumosProbe.Arm(self))
                Log("[MP_PROBE] probe=lumos status=BLOCKED reason=arm-failed");
        }
    }
    if ((RuntimeProbe ~= "Pickup") || (RuntimeProbe ~= "PickupNet"))
    {
        if (RuntimeProbe ~= "PickupNet")
            PickupProbe = Spawn(Class'HPCoopPickupNetProbe', self, 'HPCoopPickupFixtureEvent');
        else
            PickupProbe = Spawn(Class'HPCoopPickupProbe', self, 'HPCoopPickupFixtureEvent');
        if (PickupProbe != None)
        {
            PickupProbe.bOptIn = True;
            if (!PickupProbe.Arm(self))
                Log("[MP_PROBE] probe=pickup status=BLOCKED reason=arm-failed");
        }
    }
    if (RuntimeProbe ~= "AIInspect") Spawn(Class'HPCoopAIInspectProbe', self);
    if ((RuntimeProbe ~= "AICombat") || (RuntimeProbe ~= "AICombatDeath"))
        Spawn(Class'HPCoopAICombatProbe', self);
    if (RuntimeProbe ~= "AISnail") Spawn(Class'HPCoopAISnailProbe', self);
    if (RuntimeProbe ~= "Travel") Spawn(Class'HPCoopTravelProbe', self);
    if ((RuntimeProbe ~= "MountRootB0") || (RuntimeProbe ~= "MountRootB1"))
        Spawn(Class'HPCoopMountRootProbe', self);
    if (LegacyStoryHarry == None)
        LegacyStoryHarry = harry(Level.PlayerHarryActor);
    CampaignState = Spawn(Class'HPCoopCampaignState', self);
    if (CampaignState != None && !CampaignState.CaptureFrom(LegacyStoryHarry, TestStage))
        Log("[MP_STORY_STATE] initial snapshot unavailable; login will remain closed");
    // Retain the canonical map actor until a real connection is available.
    // Its story fields may be needed by native game-state screening.
    if (LegacyStoryHarry != None && HPCoopHarry(LegacyStoryHarry) == None)
    {
        LegacyStoryHarry.bHidden = True;
        // M212's native screening runs after PostBeginPlay and selects the
        // first IsPlayer pawn. Retain this flag until the later network Login.
        LegacyStoryHarry.SetCollision(False, False, False);
        LegacyStoryHarry.Disable('Tick');
        CanonicalCutName = LegacyStoryHarry.CutName;
    }
}

function bool AllowCoopFirstIntroPlay(CutScene Scene)
{
    if (!bCoopFirstIntroPreflight) return True;
    if (IntroCoordinator == None) return False;
    return IntroCoordinator.AllowPlay(Scene);
}

function SetStoryCaptured(bool bCapture)
{
    local byte I;
    local HPCoopHarry H;
    if (Role != ROLE_Authority || bStoryCaptured == bCapture) return;
    if (!bCapture && IntroCoordinator != None && IntroCoordinator.IsActive()
        && !IntroCoordinator.BeginRelease()) return;
    bStoryCaptured = bCapture;
    if (bCapture && IntroCoordinator != None && IntroCoordinator.Phase == 1)
        bCoopCapturedAuthorityUsed = True;
    if (HPCoopGRI(GameReplicationInfo) != None)
        HPCoopGRI(GameReplicationInfo).bStoryCaptured = bCapture;
    if (StoryView != None && StoryLeader != None)
        StoryView.SetCoopCapture(bCapture, StoryLeader.Cam, StoryLeader);
    for (I = 0; I < 2; I++)
    {
        H = CoopPlayers[I];
        if (H == None || H.bDeleteMe) continue;
        H.bCoopStoryCaptured = bCapture;
        H.bIsCaptured = bCapture;
        H.bKeepStationary = bCapture;
        if (bCapture)
        {
            H.Velocity = vect(0,0,0);
            H.Acceleration = vect(0,0,0);
        }
        if (bCapture && IntroCoordinator != None && IntroCoordinator.Phase == 1
            && IntroCoordinator.IsMember(H))
            H.BeginCoopAuthorityCapture(StoryView);
        else if (bCapture && bCoopCapturedAuthorityDiagnostic
            && (!bCoopCapturedAuthorityUsed
                || (IntroCoordinator != None && IntroCoordinator.Phase == 5))
            && H == StoryLeader && ReadyPlayers[I] != 0 && IsAliveCoopPlayer(H)
            && H.RemoteRole == ROLE_AutonomousProxy)
        {
            bCoopCapturedAuthorityUsed = True;
            H.BeginCoopAuthorityCapture(StoryView);
        }
        else if (!bCapture && H.bCoopSceneMode)
            H.EndCoopAuthorityCapture();
        else
            H.ClientCoopCapture(bCapture, StoryView, H.Location, H.Rotation);
    }
    Log("[MP_CUTSCENE] shared-capture=" $ bCapture $ " leader=" $ StoryLeader);
}

function BroadcastCoopSubtitle(string Text, float Duration)
{
    local byte I;
    if (Role != ROLE_Authority) return;
    for (I = 0; I < 2; I++)
        if (CoopPlayers[I] != None && !CoopPlayers[I].bDeleteMe)
            CoopPlayers[I].ClientCoopSubtitle(Text, Duration);
}

function HPCoopHarry GetStoryLeader()
{
    return StoryLeader;
}

function HPCoopHarry GetCoopPlayerBySlot(byte Slot)
{
    if (Slot < 2)
        return CoopPlayers[Slot];
    return None;
}

function bool IsCoopPlayer(Actor A)
{
    return A != None && (A == CoopPlayers[0] || A == CoopPlayers[1]);
}

function bool IsAliveCoopPlayer(HPCoopHarry H)
{
    // Original Harry damage changes StatusItemHealth, not Pawn.Health.
    return H != None && !H.bDeleteMe && H.Player != None
        && IsCoopPlayer(H) && H.managerStatus != None && !H.HarryIsDead();
}

function int GetAliveCoopPlayers(out HPCoopHarry First, out HPCoopHarry Second)
{
    local byte I;
    local int Count;
    First = None;
    Second = None;
    for (I = 0; I < 2; I++)
        if (IsAliveCoopPlayer(CoopPlayers[I]))
        {
            if (Count == 0)
                First = CoopPlayers[I];
            else
                Second = CoopPlayers[I];
            Count++;
        }
    return Count;
}

function bool IsCh1CombatSeeker(Pawn Seeker)
{
    return Seeker != None && Seeker.Level == Level
        && (string(Level.Outer.Name) ~= "Ch1Rictusempra")
        && (Seeker.Class == Class'orangesnail'
            || Seeker.Class == Class'firecrabSmall');
}

function bool IsCh1CombatOpen(Pawn Seeker)
{
    if (Role != ROLE_Authority || Level.NetMode == NM_Client
        || !IsCh1CombatSeeker(Seeker) || Seeker.Role != ROLE_Authority
        || Seeker.bDeleteMe || Seeker.bHidden || !Seeker.bInCurrentGameState
        || Seeker.CutNotifyActor != None || Seeker.IsInState('stateCutCapture')
        || Seeker.IsInState('CutIdle') || bWaitingForPlayers || bStoryCaptured
        || bCoopRecoveryBlocked || Level.Pauser != ""
        || (IntroCoordinator != None
            && (IntroCoordinator.IsActive() || IntroCoordinator.Phase == 6))) return False;
    // Keep the original three-second post-cut delay, including contact damage.
    if (orangesnail(Seeker) != None && orangesnail(Seeker).bCutInProgress)
        return False;
    return True;
}

function bool IsAIPlayerAvailable(HPCoopHarry H)
{
    local byte I;
    if (Role != ROLE_Authority || Level.NetMode == NM_Client
        || bWaitingForPlayers || bStoryCaptured || bCoopRecoveryBlocked
        || Level.Pauser != "" || !IsAliveCoopPlayer(H) || H.Level != Level
        || H.Role != ROLE_Authority || H.bCoopStoryCaptured || H.bCoopAwaitResume
        || H.bIsCaptured || H.CutNotifyActor != None
        || H.bCoopSceneMode || H.bCoopSceneAwaitRelease || H.bCoopIntroInputHold
        || (IntroCoordinator != None
            && (IntroCoordinator.IsActive() || IntroCoordinator.Phase == 6))) return False;
    for (I = 0; I < 2; I++)
        if (CoopPlayers[I] == H && ReadyPlayers[I] != 0) return True;
    return False;
}

function bool CanAITarget(Pawn Seeker, HPCoopHarry H, float MaxRange,
    optional bool bUsePeripheralVision)
{
    if (!IsCh1CombatOpen(Seeker) || !IsAIPlayerAvailable(H)
        || MaxRange <= 0 || VSize(H.Location - Seeker.Location) >= MaxRange)
        return False;
    if (bUsePeripheralVision) return Seeker.CanSee(H);
    return Seeker.LineOfSightTo(H);
}

function HPCoopHarry ResolveAITarget(Pawn Seeker, optional Pawn Attacker,
    optional float MaxRange, optional bool bUsePeripheralVision)
{
    local byte I;
    local HPCoopHarry Candidate, Best;
    local float Distance, BestDistance;
    if (!IsCh1CombatOpen(Seeker)) return None;
    // Retain the existing two-argument call shape. Crab map instances include
    // attack range 700 with SightRadius 500; do not clamp that to SightRadius.
    if (MaxRange <= 0)
    {
        if (firecrabSmall(Seeker) != None)
            MaxRange = firecrabSmall(Seeker).fAttackRange;
        else MaxRange = Seeker.SightRadius;
    }
    // A proven spell attacker may be behind the snail, but cannot be attacked
    // through a wall, out of range, while dead/unready, or during capture.
    Candidate = HPCoopHarry(Attacker);
    if (CanAITarget(Seeker, Candidate, MaxRange, False)) return Candidate;
    for (I = 0; I < 2; I++)
    {
        Candidate = CoopPlayers[I];
        if (CanAITarget(Seeker, Candidate, MaxRange, bUsePeripheralVision))
        {
            Distance = VSize(Candidate.Location - Seeker.Location);
            if (Best == None || Distance < BestDistance)
            {
                Best = Candidate;
                BestDistance = Distance;
            }
        }
    }
    // Stable ties use registry order. No story alias assignment is performed.
    return Best;
}

function RefreshSession()
{
    local byte I, Count, ReadyCount;
    local HPCoopGRI G;
    local HPCoopPRI P;
    G = HPCoopGRI(GameReplicationInfo);
    for (I = 0; I < 2; I++)
        if (CoopPlayers[I] != None)
        {
            Count++;
            if (ReadyPlayers[I] != 0 && IsAliveCoopPlayer(CoopPlayers[I]))
                ReadyCount++;
            P = HPCoopPRI(CoopPlayers[I].PlayerReplicationInfo);
            if (P != None)
            {
                P.CoopSlot = I;
                P.bStoryLeader = CoopPlayers[I] == StoryLeader;
            }
        }
    if (StoryLeader != None)
        Level.PlayerHarryActor = StoryLeader;
    else
        Level.PlayerHarryActor = LegacyStoryHarry;
    if (G != None)
    {
        G.StoryLeader = StoryLeader;
        G.ConnectedPlayers = Count;
        if (StoryLeader != None)
            G.SharedGameState = StoryLeader.CurrentGameState;
    }
    if (bWaitingForPlayers && ReadyCount >= RequiredPlayers)
    {
        bWaitingForPlayers = False;
        if (Level.Pauser == "WaitingForCoopPlayers")
            Level.Pauser = "";
        Log("[MP_STORY] session-ready players=" $ Count $ " ready=" $ ReadyCount $ " leader=" $ StoryLeader);
    }
}

function PlayerContextReady(HPCoopHarry H)
{
    local byte I;
    // Called by the owning pawn's server RPC after its local context is ready.
    // Resolve the slot through the registry; never trust a supplied slot value.
    if (Role != ROLE_Authority || !IsAliveCoopPlayer(H))
        return;
    for (I = 0; I < 2; I++)
        if (CoopPlayers[I] == H)
        {
            if (ReadyPlayers[I] == 0)
            {
                ReadyPlayers[I] = 1;
                Log("[MP_LOGIN] context-ready pawn=" $ H $ " slot=" $ I);
            }
            RefreshSession();
            return;
        }
}

function bool SetPause(bool bPause, PlayerPawn P)
{
    // The lobby owns this pause until the required clients acknowledge ready.
    if (bWaitingForPlayers || (IntroCoordinator != None
        && (IntroCoordinator.IsActive() || IntroCoordinator.Phase == 6)))
        return False;
    return Super.SetPause(bPause, P);
}

function AdoptStoryLeader(HPCoopHarry NewLeader, harry Previous)
{
    local HPawn A;
    local Director D;
    local harry Canonical;
    StoryLeader = NewLeader;
    Canonical = NewLeader;
    if (Canonical == None)
        Canonical = LegacyStoryHarry;
    if (Canonical != None)
    {
        if (Previous != None && Previous != Canonical)
        {
            Canonical.CurrentGameState = Previous.CurrentGameState;
            if (CanonicalCutName == "") CanonicalCutName = Previous.CutName;
            Previous.CutName = "";
        }
        Canonical.CutName = CanonicalCutName;
    }
    // Only migrate references to the previous canonical actor. This is not an
    // AI targeting policy and does not touch independent carry/combat owners.
    // Last logout migrates them back to the retained map actor before the
    // departing pawn is destroyed, so the next login can adopt them again.
    if (Previous != None)
    {
        foreach AllActors(Class'HPawn', A)
            if (A.PlayerHarry == Previous)
                A.PlayerHarry = Canonical;
        foreach AllActors(Class'Director', D)
            if (D.PlayerHarry == Previous)
                D.PlayerHarry = Canonical;
    }
    Level.PlayerHarryActor = Canonical;
}

event PlayerPawn Login(string Portal, string Options, out string Error, class<PlayerPawn> SpawnClass)
{
    local PlayerPawn P;
    local HPCoopHarry H;
    if (ParseOption(Options, "MPMode") != ""
        && !(ParseOption(Options, "MPMode") ~= "Coop"))
    {
        Error = "This server is running Co-op, not the selected mode.";
        return None;
    }
    if (IntroCoordinator != None && IntroCoordinator.Phase == 6)
    {
        Error = "This intro session failed. A fresh host is required.";
        return None;
    }
    if (CampaignState == None || !CampaignState.IsSnapshotReady())
    {
        Error = "The initial co-op campaign snapshot is unavailable.";
        return None;
    }
    if (CoopPlayers[0] != None && CoopPlayers[1] != None)
    {
        Error = "Campaign co-op supports two players.";
        return None;
    }
    PendingLoginSlot = 0;
    if (CoopPlayers[0] != None)
        PendingLoginSlot = 1;
    bLoginInProgress = True;
    if ((RuntimeProbe ~= "MountRootB0") || (RuntimeProbe ~= "MountRootB1"))
        P = Super.Login(Portal, Options, Error, Class'HPCoopMountTrialHarry');
    else
        P = Super.Login(Portal, Options, Error, Class'HPCoopHarry');
    bLoginInProgress = False;
    H = HPCoopHarry(P);
    if (H == None)
    {
        Error = "Co-op requires a separate HPCoopHarry for each connection.";
        if (P != None)
        {
            Super.Logout(P);
            P.Destroy();
        }
        return None;
    }
    H.bFraserMode = False;
    H.CoopSlot = PendingLoginSlot;
    H.CoopCampaignState = CampaignState;
    H.bCoopProgressApplied = CampaignState.ApplyTo(H);
    CoopPlayers[PendingLoginSlot] = H;
    ReadyPlayers[PendingLoginSlot] = 0;
    if (StoryLeader == None)
        AdoptStoryLeader(H, LegacyStoryHarry);
    else
    {
        H.CurrentGameState = StoryLeader.CurrentGameState;
        H.CutName = "CoopCompanion";
    }
    RefreshSession();
    if (LegacyStoryHarry != None)
        LegacyStoryHarry.bIsPlayer = False;
    Log("[MP_LOGIN] accepted pawn=" $ H $ " slot=" $ H.CoopSlot $ " leader=" $ StoryLeader);
    return P;
}

event PostLogin(PlayerPawn NewPlayer)
{
    Super.PostLogin(NewPlayer);
    if (HPCoopHarry(NewPlayer) != None)
    {
        HPCoopHarry(NewPlayer).EnsureCoopWand();
        Log("[MP_LOGIN] post-login pawn=" $ NewPlayer $ " weapon=" $ NewPlayer.Weapon);
        HPCoopHarry(NewPlayer).ClientCoopReady(HPCoopHarry(NewPlayer).CoopSlot);
        if (bStoryCaptured)
        {
            HPCoopHarry(NewPlayer).bCoopStoryCaptured = True;
            HPCoopHarry(NewPlayer).bIsCaptured = True;
            HPCoopHarry(NewPlayer).bKeepStationary = True;
            HPCoopHarry(NewPlayer).ClientCoopCapture(True, StoryView, NewPlayer.Location, NewPlayer.Rotation);
        }
    }
}

function NavigationPoint FindPlayerStart(Pawn Player, optional byte InTeam, optional string incomingName)
{
    local NavigationPoint Start;
    local vector Candidate, HitLocation, HitNormal, Offset;
    local int I;
    local byte Slot;
    Start = Super.FindPlayerStart(Player, InTeam, incomingName);
    Slot = PendingLoginSlot;
    if (HPCoopHarry(Player) != None)
        Slot = HPCoopHarry(Player).CoopSlot;
    if (Start == None || Slot == 0)
        return Start;
    if (CompanionStart != None)
        return CompanionStart;
    for (I = 0; I < 4; I++)
    {
        Offset = vect(0,0,0);
        if (I == 0) Offset.X = 96;
        if (I == 1) Offset.X = -96;
        if (I == 2) Offset.Y = 96;
        if (I == 3) Offset.Y = -96;
        Candidate = Start.Location + Offset;
        if (Trace(HitLocation, HitNormal, Candidate, Start.Location, True, vect(24,24,42)) == None)
        {
            CompanionStart = Spawn(Class'HPCoopStart', self,,Candidate,Start.Rotation);
            if (CompanionStart != None)
            {
                Log("[MP_LOGIN] companion-start=" $ CompanionStart $ " location=" $ Candidate);
                return CompanionStart;
            }
        }
    }
    Log("[MP_LOGIN] rejected reason=no-companion-start");
    return None;
}


function CoopPlayerDied(HPCoopHarry Victim)
{
    local HPCoopHarry A, B;
    if (Role != ROLE_Authority || !IsCoopPlayer(Victim)) return;
    if (IntroCoordinator != None && IntroCoordinator.IsActive())
        IntroCoordinator.Fail("participant-died");
    if (GetAliveCoopPlayers(A, B) == 0 && !bCoopRecoveryBlocked)
    {
        bCoopRecoveryBlocked = True;
        // Do not pause net ticking: owner RPCs must still be delivered.
        Log("[MP_CHECKPOINT] blocked reason=all-dead-no-verified-shared-checkpoint");
        BroadcastCoopSubtitle("Both players have fallen. Shared checkpoint recovery is not implemented.", 30);
    }
}

function bool IsSpentCoopScene(Actor A)
{
    local CutScene S;
    // Exact original class only: its Finished state has no touch handler and
    // Play rejects an already played one-shot. Keep every other trigger unsafe.
    if (A == None || A.Class != Class'CutScene' || A.Level != Level
        || A.bBlockActors || A.bBlockPlayers) return False;
    S = CutScene(A);
    return S.bPlayOnce && S.nPlayedCount > 0 && S.IsInState('Finished')
        && !S.bPlaying && !S.bFastForwarding;
}

function bool IsPassiveCoopOverlap(Actor A)
{
    local MusicTrigger M;
    if (IsSpentCoopScene(A)) return True;
    // These exact classes only change music in Activate. Inherited UnTouch
    // and MusicTrackLooped can dispatch Event, so require an empty event and
    // no loop callback. A respawn may refresh ambient music, never story state.
    if (A == None || A.Level != Level || A.bBlockActors || A.bBlockPlayers
        || (A.Class != Class'NewMusicTrigger' && A.Class != Class'MusicTrigger'))
        return False;
    M = MusicTrigger(A);
    return M.Event == '' && !M.bEventOnMusicLoop;
}

function bool TryCoopReviveNear(HPCoopHarry Fallen, HPCoopHarry Alive)
{
    local int I;
    local vector Candidate, Top, Bottom, HitLocation, HitNormal, Extent, OldLocation;
    local rotator Direction;
    local Actor FloorActor, Obstacle;
    local Actor FirstOverlap;
    local int BadFloor, BadHeight, BadLine, BadClearance, BadOverlap, BadPlacement;
    local string FloorExample;
    if (!IsCoopPlayer(Fallen) || !Fallen.bCoopDead || !IsAliveCoopPlayer(Alive)
        || Alive.Physics != PHYS_Walking
        || Alive.bCoopStoryCaptured || bStoryCaptured)
    {
        if (RuntimeProbe ~= "Health")
            Log("[MP_RESPAWN] candidate-refused reason=precondition fallen=" $ Fallen
                $ " partner=" $ Alive);
        return False;
    }
    // A conservative first implementation uses static BSP floors only.
    // A moving platform requires an audited base-relative recovery contract.
    if (Alive.Base != None && Alive.Base != Level)
    {
        if (RuntimeProbe ~= "Health")
            Log("[MP_RESPAWN] candidate-refused reason=non-bsp-base base=" $ Alive.Base);
        return False;
    }
    Extent.X = Fallen.CollisionRadius;
    Extent.Y = Fallen.CollisionRadius;
    Extent.Z = Fallen.CollisionHeight;
    OldLocation = Fallen.Location;
    for (I = 0; I < 8; I++)
    {
        Direction = Alive.Rotation;
        Direction.Pitch = 0;
        Direction.Roll = 0;
        Direction.Yaw += I * 8192;
        Candidate = Alive.Location + vector(Direction) * (Alive.CollisionRadius + Fallen.CollisionRadius + 48);
        Top = Candidate + vect(0,0,64);
        Bottom = Candidate - vect(0,0,160);
        FloorActor = Trace(HitLocation, HitNormal, Bottom, Top, True,
            Extent * vect(1,1,0));
        if (FloorActor != Level || HitNormal.Z < 0.7)
        {
            BadFloor++;
            FloorExample = string(FloorActor) $ " normal=" $ HitNormal;
            continue;
        }
        Candidate = HitLocation + vect(0,0,1) * (Fallen.CollisionHeight + 2);
        if (Abs(Candidate.Z - Alive.Location.Z) > 48) { BadHeight++; continue; }
        // Reachability from the living player's side of a wall is required.
        if (!FastTrace(Candidate, Alive.Location)) { BadLine++; continue; }
        if (Trace(HitLocation, HitNormal, Candidate + vect(0,0,1), Candidate, True, Extent) != None)
        { BadClearance++; continue; }
        // Avoid every overlapping colliding actor, including triggers/hazards.
        // This deliberately rejects more positions than ordinary pawn blocking.
        Obstacle = None;
        // M212 has no CollidingActors iterator. Test the collision flags and
        // cylinders explicitly, including large actors whose origin is far away.
        foreach AllActors(Class'Actor', FloorActor)
            if (FloorActor != Fallen && FloorActor != Level && FloorActor.bCollideActors
                && !IsPassiveCoopOverlap(FloorActor)
                && Abs(FloorActor.Location.Z - Candidate.Z) < FloorActor.CollisionHeight + Extent.Z + 2
                && VSize((FloorActor.Location - Candidate) * vect(1,1,0)) < FloorActor.CollisionRadius + Extent.X + 2)
            {
                Obstacle = FloorActor;
                break;
            }
        if (Obstacle != None)
        {
            BadOverlap++;
            if (FirstOverlap == None) FirstOverlap = Obstacle;
            continue;
        }
        if (!Fallen.CanFit(Fallen.CollisionRadius, Fallen.CollisionHeight,
            Fallen.CollisionWidth, Candidate, Alive.Rotation))
        { BadClearance++; continue; }
        Fallen.bCollideWorld = True;
        if (!Fallen.SetLocation(Candidate)) { BadPlacement++; continue; }
        if (VSize(Fallen.Location - Candidate) > 1 || Fallen.Region.Zone == None
            || Fallen.Region.Zone.bKillZone || Fallen.Region.Zone.bPainZone
            || Fallen.Region.Zone.bWaterZone)
        {
            BadPlacement++;
            Fallen.SetLocation(OldLocation);
            continue;
        }
        Fallen.FinishCoopRevive(Alive.Rotation);
        Log("[MP_RESPAWN] victim=" $ Fallen $ " partner=" $ Alive
            $ " location=" $ Fallen.Location $ " health=" $ Fallen.GetHealthCount());
        return True;
    }
    if (RuntimeProbe ~= "Health")
        Log("[MP_RESPAWN] candidate-refused partner-location=" $ Alive.Location
            $ " radius=" $ Extent.X $ " height=" $ Extent.Z
            $ " floor=" $ BadFloor $ " height-delta=" $ BadHeight
            $ " line=" $ BadLine $ " clearance=" $ BadClearance
            $ " overlap=" $ BadOverlap $ " placement=" $ BadPlacement
            $ " first-overlap=" $ FirstOverlap $ " floor-example=" $ FloorExample);
    return False;
}

event Tick(float DeltaTime)
{
    local HPCoopHarry A, B, H;
    local byte I;
    Super.Tick(DeltaTime);
    if (Role == ROLE_Authority)
        for (I = 0; I < 2; I++)
            if (CoopPlayers[I] != None && !CoopPlayers[I].bDeleteMe)
                CoopPlayers[I].CoopAuthorityTick(DeltaTime);
    if (Role != ROLE_Authority || bWaitingForPlayers || bStoryCaptured
        || bCoopRecoveryBlocked) return;
    GetAliveCoopPlayers(A, B);
    if (A == None) return;
    for (I = 0; I < 2; I++)
    {
        H = CoopPlayers[I];
        if (H == None || !H.bCoopDead || !H.bCoopDeathAnimFinished
            || Level.TimeSeconds < H.CoopRespawnAfter) continue;
        H.CoopRespawnAfter = Level.TimeSeconds + 1;
        TryCoopReviveNear(H, A);
    }
}

// Generic engine restart sets Pawn.Health and PlayerStart, not original
// StatusItemHealth or campaign checkpoints. It is not a valid fallback.
function bool RestartPlayer(Pawn P)
{
    if (HPCoopHarry(P) != None) return False;
    return Super.RestartPlayer(P);
}

function Logout(Pawn Exiting)
{
    local byte I;
    local HPCoopHarry Successor;
    if (IntroCoordinator != None && IntroCoordinator.IsActive()
        && IntroCoordinator.IsMember(HPCoopHarry(Exiting)))
        IntroCoordinator.Fail("participant-disconnected");
    for (I = 0; I < 2; I++)
        if (CoopPlayers[I] == Exiting)
        {
            CoopPlayers[I] = None;
            ReadyPlayers[I] = 0;
        }
    // Record cleanup unavailability after unregister, before the empty lobby
    // can pause coordinator Tick. No ACK from this removed pawn is accepted.
    if (IntroCoordinator != None && IntroCoordinator.Phase == 6)
        IntroCoordinator.CheckFailureCleanup();
    if (StoryLeader == Exiting)
    {
        Successor = CoopPlayers[0];
        if (Successor == None)
            Successor = CoopPlayers[1];
        if (IntroCoordinator != None && IntroCoordinator.Phase == 6)
            StoryLeader = None;
        else
            AdoptStoryLeader(Successor, harry(Exiting));
    }
    Super.Logout(Exiting);
    if (CoopPlayers[0] == None && CoopPlayers[1] == None)
    {
        ReadyPlayers[0] = 0;
        ReadyPlayers[1] = 0;
        bWaitingForPlayers = True;
        Level.Pauser = "WaitingForCoopPlayers";
        Log("[MP_STORY] waiting-for-players reason=empty-session");
    }
    RefreshSession();
    Log("[MP_LOGIN] logout pawn=" $ Exiting $ " leader=" $ StoryLeader);
}

defaultproperties
{
    bCoopCapturedAuthorityDiagnostic=False
    GameName="Harry Potter Campaign Co-op"
    MaxPlayers=2
    DefaultPlayerClass=Class'HPCoopHarry'
    GameReplicationInfoClass=Class'HPCoopGRI'
    HUDType=Class'HPHud'
}
