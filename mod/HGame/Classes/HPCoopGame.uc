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

event InitGame(string Options, out string Error)
{
    Super.InitGame(Options, Error);
    MaxPlayers = 2;
    RequiredPlayers = Clamp(GetIntOption(Options, "RequiredPlayers", 2), 1, 2);
    bWaitingForPlayers = True;
    Level.Pauser = "WaitingForCoopPlayers";
    Log("[MP_LOGIN] mode=coop build=foundation-1 maxPlayers=2");
}

event PostBeginPlay()
{
    local CutScene Scene;
    Super.PostBeginPlay();
    // The two entry scenes observed on the selected milestone map. Only their
    // logging is adapted; the original command/cue interpreter runs on server.
    foreach AllActors(Class'CutScene', Scene)
        if (Scene.FileName ~= "Ch1RictuIntro" || Scene.FileName ~= "02080Ch1FireCrabIntro")
        {
            Scene.CutscriptDiskClass = Class'HPCoopCutScriptDisk';
        }
    StoryView = Spawn(Class'HPCoopCutsceneView', self);
    LegacyStoryHarry = harry(Level.PlayerHarryActor);
    // Retain the canonical map actor until a real connection is available.
    // Its story fields may be needed by native game-state screening.
    if (LegacyStoryHarry != None && HPCoopHarry(LegacyStoryHarry) == None)
    {
        LegacyStoryHarry.bHidden = True;
        LegacyStoryHarry.bIsPlayer = False;
        LegacyStoryHarry.SetCollision(False, False, False);
        LegacyStoryHarry.Disable('Tick');
        CanonicalCutName = LegacyStoryHarry.CutName;
    }
}

function SetStoryCaptured(bool bCapture)
{
    local byte I;
    local HPCoopHarry H;
    if (Role != ROLE_Authority || bStoryCaptured == bCapture) return;
    bStoryCaptured = bCapture;
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

function HPCoopHarry ResolveAITarget(Pawn Seeker, optional Pawn Attacker)
{
    local HPCoopHarry A, B;
    GetAliveCoopPlayers(A, B);
    if (IsAliveCoopPlayer(HPCoopHarry(Attacker)))
        return HPCoopHarry(Attacker);
    if (A == None || Seeker == None)
        return A;
    if (B != None && VSize(B.Location - Seeker.Location) < VSize(A.Location - Seeker.Location))
        return B;
    return A;
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
    if (bWaitingForPlayers)
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
    if (CoopPlayers[0] != None && CoopPlayers[1] != None)
    {
        Error = "Campaign co-op supports two players.";
        return None;
    }
    PendingLoginSlot = 0;
    if (CoopPlayers[0] != None)
        PendingLoginSlot = 1;
    bLoginInProgress = True;
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
    H.CoopSlot = PendingLoginSlot;
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
            CompanionStart = Spawn(Class'PlayerStart',,,Candidate,Start.Rotation);
            if (CompanionStart != None)
                return CompanionStart;
        }
    }
    return Start;
}

function Logout(Pawn Exiting)
{
    local byte I;
    local HPCoopHarry Successor;
    for (I = 0; I < 2; I++)
        if (CoopPlayers[I] == Exiting)
        {
            CoopPlayers[I] = None;
            ReadyPlayers[I] = 0;
        }
    if (StoryLeader == Exiting)
    {
        Successor = CoopPlayers[0];
        if (Successor == None)
            Successor = CoopPlayers[1];
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
    GameName="Harry Potter Campaign Co-op"
    MaxPlayers=2
    DefaultPlayerClass=Class'HPCoopHarry'
    GameReplicationInfoClass=Class'HPCoopGRI'
    HUDType=Class'HPHud'
}
