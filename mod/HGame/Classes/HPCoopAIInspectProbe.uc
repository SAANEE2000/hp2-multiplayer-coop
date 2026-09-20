// Passive, opt-in observation of original Ch1 enemy state and co-op targets.
// No pawn, enemy, collision, state or story mutation is performed.
class HPCoopAIInspectProbe extends Info;

var HPCoopGame Game;
var HPawn Seen[64];
var harry LastTarget[64];
var name LastState[64];
var int SeenCount;
var bool bStarted;
var float Deadline, EndAt;

event PostBeginPlay()
{
    Super.PostBeginPlay();
    Game = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || Level.NetMode != NM_DedicatedServer
        || Game == None || !(Game.RuntimeProbe ~= "AIInspect")
        || !(Game.TestStage ~= "RictusempraLessonComplete"))
    {
        Destroy();
        return;
    }
    Deadline = Level.TimeSeconds + 160;
    SetTimer(0.5, True);
    Log("[MP_AI_INSPECT] armed passive=True input-test=False visual-test=False");
}

function bool PairReleased()
{
    local HPCoopHarry A, B;
    if (Game == None || Game.bWaitingForPlayers || Game.bStoryCaptured
        || Game.ReadyPlayers[0] == 0 || Game.ReadyPlayers[1] == 0
        || Game.GetAliveCoopPlayers(A, B) != 2
        || A == None || B == None || A.Player == None || B.Player == None
        || !A.IsInState('PlayerWalking') || !B.IsInState('PlayerWalking'))
        return False;
    if (Game.IntroCoordinator != None && Game.IntroCoordinator.Phase != 5) return False;
    return True;
}

function PrintEnemy(HPawn P, int Index, bool bInitial)
{
    local HPCoopHarry A, B;
    local float Range;
    Game.GetAliveCoopPlayers(A, B);
    Range = P.SightRadius;
    if (firecrabSmall(P) != None) Range = firecrabSmall(P).fAttackRange;
    Log("[MP_AI_INSPECT] enemy=" $ P $ " class=" $ P.Class
        $ " initial=" $ bInitial $ " state=" $ P.GetStateName()
        $ " current=" $ P.bInCurrentGameState $ " hidden=" $ P.bHidden
        $ " cut=" $ P.CutNotifyActor $ " open=" $ Game.IsCh1CombatOpen(P)
        $ " target=" $ P.CoopCombatTarget $ " range=" $ Range
        $ " dist0=" $ VSize(P.Location - A.Location)
        $ " dist1=" $ VSize(P.Location - B.Location)
        $ " los0=" $ P.LineOfSightTo(A) $ " los1=" $ P.LineOfSightTo(B));
    Seen[Index] = P;
    LastTarget[Index] = P.CoopCombatTarget;
    LastState[Index] = P.GetStateName();
}

event Timer()
{
    local HPawn P;
    local int I;
    if (Level.TimeSeconds > Deadline)
    {
        Log("[MP_AI_INSPECT] BLOCKED reason=pair-or-intro-not-released");
        SetTimer(0, False);
        Destroy();
        return;
    }
    if (!bStarted)
    {
        if (!PairReleased()) return;
        bStarted = True;
        EndAt = Level.TimeSeconds + 12;
        foreach AllActors(Class'HPawn', P)
            if (P.Class == Class'orangesnail' || P.Class == Class'firecrabSmall')
            {
                if (SeenCount >= 64) break;
                PrintEnemy(P, SeenCount, True);
                SeenCount++;
            }
        Log("[MP_AI_INSPECT] snapshot enemies=" $ SeenCount
            $ " players=" $ Game.CoopPlayers[0] $ "," $ Game.CoopPlayers[1]);
        return;
    }
    for (I = 0; I < SeenCount; I++)
    {
        P = Seen[I];
        if (P == None || P.bDeleteMe) continue;
        if (P.CoopCombatTarget != LastTarget[I] || P.GetStateName() != LastState[I])
            PrintEnemy(P, I, False);
    }
    if (Level.TimeSeconds >= EndAt)
    {
        Log("[MP_AI_INSPECT] complete passive=True tracked=" $ SeenCount);
        SetTimer(0, False);
        Destroy();
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
