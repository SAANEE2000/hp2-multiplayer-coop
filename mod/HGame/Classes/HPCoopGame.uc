// Campaign session authority, deliberately independent of Versus match logic.
class HPCoopGame extends GameInfo;

var HPCoopHarry CoopPlayers[2];
var HPCoopHarry StoryLeader;
var harry LegacyStoryHarry;
var byte PendingLoginSlot;
var bool bLoginInProgress;
var PlayerStart CompanionStart;

event InitGame(string Options, out string Error)
{
    Super.InitGame(Options, Error);
    MaxPlayers = 2;
    Log("[MP_LOGIN] mode=coop build=foundation-1 maxPlayers=2");
}

event PostBeginPlay()
{
    Super.PostBeginPlay();
    LegacyStoryHarry = harry(Level.PlayerHarryActor);
    // Retain the canonical map actor until a real connection is available.
    // Its story fields may be needed by native game-state screening.
    if (LegacyStoryHarry != None && HPCoopHarry(LegacyStoryHarry) == None)
    {
        LegacyStoryHarry.bHidden = True;
        LegacyStoryHarry.SetCollision(False, False, False);
        LegacyStoryHarry.Disable('Tick');
    }
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

function int GetAliveCoopPlayers(out HPCoopHarry First, out HPCoopHarry Second)
{
    local byte I;
    local int Count;
    First = None;
    Second = None;
    for (I = 0; I < 2; I++)
        if (CoopPlayers[I] != None && CoopPlayers[I].Player != None
            && CoopPlayers[I].Health > 0 && !CoopPlayers[I].bDeleteMe)
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
    if (IsCoopPlayer(Attacker) && Attacker.Health > 0)
        return HPCoopHarry(Attacker);
    if (A == None || Seeker == None)
        return A;
    if (B != None && VSize(B.Location - Seeker.Location) < VSize(A.Location - Seeker.Location))
        return B;
    return A;
}

function RefreshSession()
{
    local byte I, Count;
    local HPCoopGRI G;
    local HPCoopPRI P;
    G = HPCoopGRI(GameReplicationInfo);
    for (I = 0; I < 2; I++)
        if (CoopPlayers[I] != None)
        {
            Count++;
            P = HPCoopPRI(CoopPlayers[I].PlayerReplicationInfo);
            if (P != None)
            {
                P.CoopSlot = I;
                P.bStoryLeader = CoopPlayers[I] == StoryLeader;
            }
        }
    if (StoryLeader != None)
        Level.PlayerHarryActor = StoryLeader;
    if (G != None)
    {
        G.StoryLeader = StoryLeader;
        G.ConnectedPlayers = Count;
        if (StoryLeader != None)
            G.SharedGameState = StoryLeader.CurrentGameState;
    }
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
        return P;
    H.CoopSlot = PendingLoginSlot;
    CoopPlayers[PendingLoginSlot] = H;
    if (StoryLeader == None)
    {
        StoryLeader = H;
        if (LegacyStoryHarry != None)
            H.CurrentGameState = LegacyStoryHarry.CurrentGameState;
    }
    RefreshSession();
    Log("[MP_LOGIN] accepted pawn=" $ H $ " slot=" $ H.CoopSlot $ " leader=" $ StoryLeader);
    return P;
}

event PostLogin(PlayerPawn NewPlayer)
{
    Super.PostLogin(NewPlayer);
    if (HPCoopHarry(NewPlayer) != None)
        HPCoopHarry(NewPlayer).ClientCoopReady(HPCoopHarry(NewPlayer).CoopSlot);
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
    for (I = 0; I < 2; I++)
        if (CoopPlayers[I] == Exiting)
            CoopPlayers[I] = None;
    if (StoryLeader == Exiting)
    {
        StoryLeader = CoopPlayers[0];
        if (StoryLeader == None)
            StoryLeader = CoopPlayers[1];
    }
    Super.Logout(Exiting);
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
