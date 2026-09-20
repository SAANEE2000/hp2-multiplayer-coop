// Explicit disposable Ch1 fixture. Never spawned during ordinary play.
// Exercises real registered pawns and the original damage/animation handlers.
class HPCoopHealthProbe extends Info;

var HPCoopGame Game;
var HPCoopHarry A, B;
var StatusItem Potion;
var int Phase;
var float Deadline, NextPhase;
var bool bStarted, bPairReadySeen;

event PostBeginPlay()
{
    Super.PostBeginPlay();
    Game = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || Level.NetMode != NM_DedicatedServer
        || Game == None || !(Game.TestStage ~= "RictusempraLessonComplete")
        || !(Game.RuntimeProbe ~= "Health"))
    {
        Destroy();
        return;
    }
    Deadline = Level.TimeSeconds + 150;
    SetTimer(0.2, True);
    Log("[MP_PROBE] health armed: destructive disposable fixture; not gameplay/2-PC acceptance");
}

function Finish(string Result, string Detail)
{
    Log("[MP_PROBE] health result=" $ Result $ " phase=" $ Phase $ " detail=" $ Detail);
    SetTimer(0, False);
    Destroy();
}

function bool Check(bool Condition, string Detail)
{
    if (!Condition)
    {
        Finish("FAIL", Detail);
        return False;
    }
    Log("[MP_PROBE] health check=PASS phase=" $ Phase $ " detail=" $ Detail);
    return True;
}

function Next(int NewPhase, float Delay)
{
    Phase = NewPhase;
    NextPhase = Level.TimeSeconds + Delay;
}

event Timer()
{
    if (!bPairReadySeen)
    {
        if (Game.bWaitingForPlayers || Game.ReadyPlayers[0] == 0 || Game.ReadyPlayers[1] == 0)
            return;
        bPairReadySeen = True;
        Deadline = Level.TimeSeconds + 150;
    }
    if (Level.TimeSeconds > Deadline)
    {
        Finish("BLOCKED", "timeout waiting for ready clients, intro or recovery");
        return;
    }
    if (Level.TimeSeconds < NextPhase) return;
    if (!bStarted)
    {
        if (Game.bWaitingForPlayers || Game.bStoryCaptured || Game.StoryView == None
            || Game.StoryView.SceneSerial < 1 || Game.GetAliveCoopPlayers(A, B) != 2
            || !A.IsInState('PlayerWalking') || !B.IsInState('PlayerWalking')
            || A.Physics != PHYS_Walking || B.Physics != PHYS_Walking) return;
        bStarted = True;
        // Fixture values are explicit. This does not test inventory acquisition.
        A.bAutoQuaff = False;
        B.bAutoQuaff = False;
        A.SetHealth(100);
        B.SetHealth(100);
        Potion = A.managerStatus.GetStatusItem(Class'StatusGroupPotions', Class'StatusItemWiggenwell');
        if (!Check(Potion != None, "own potion item exists")) return;
        Potion.SetCount(0);
        A.PublishCoopStatus(True);
        B.PublishCoopStatus(True);
        Log("[MP_PROBE] health fixture=100-each slots=" $ A.CoopSlot $ "," $ B.CoopSlot);
        Next(1, 0.5);
        return;
    }
    if (A == None || B == None || A.bDeleteMe || B.bDeleteMe
        || A.Player == None || B.Player == None || Game.bStoryCaptured)
    {
        Finish("BLOCKED", "player left or a new story capture started");
        return;
    }
    switch (Phase)
    {
    case 1:
        A.Difficulty = DifficultyEasy;
        A.TakeDamage(10, None, A.Location, vect(0,0,0), 'Probe');
        if (!Check(A.GetHealthCount() == 88 && B.GetHealthCount() == 100, "easy=12 damage; other owner unchanged")) return;
        Next(2, 0.5);
        break;
    case 2:
        A.SetHealth(100);
        A.Difficulty = DifficultyMedium;
        A.TakeDamage(10, None, A.Location, vect(0,0,0), 'Probe');
        if (!Check(A.GetHealthCount() == 80 && B.GetHealthCount() == 100, "medium=20 damage; other owner unchanged")) return;
        Next(3, 0.5);
        break;
    case 3:
        A.SetHealth(100);
        A.Difficulty = DifficultyHard;
        A.TakeDamage(10, None, A.Location, vect(0,0,0), 'Probe');
        if (!Check(A.GetHealthCount() == 70, "hard=30 damage")) return;
        B.Difficulty = DifficultyMedium;
        B.TakeDamage(10, None, B.Location, vect(0,0,0), 'Probe');
        if (!Check(B.GetHealthCount() == 80 && A.GetHealthCount() == 70, "second owner takes its own damage")) return;
        Next(4, 0.5);
        break;
    case 4:
        A.SetHealth(100);
        B.SetHealth(100);
        A.Difficulty = DifficultyMedium;
        A.fTimeSinceLastAcidHit = 0;
        A.TakeDamage(10, None, A.Location, vect(0,0,0), 'AcidHit');
        if (!Check(A.GetHealthCount() == 100, "acid throttled before 0.333 seconds")) return;
        Next(5, 0.5);
        break;
    case 5:
        A.TakeDamage(10, None, A.Location, vect(0,0,0), 'AcidHit');
        if (!Check(A.GetHealthCount() == 80, "authority acid counter advanced")) return;
        A.TakeDamage(10, None, A.Location, vect(0,0,0), 'AcidHit');
        if (!Check(A.GetHealthCount() == 80, "immediate repeated acid does not subtract twice")) return;
        Next(6, 0.5);
        break;
    case 6:
        A.SetHealth(50);
        Potion.SetCount(2);
        A.ServerCoopDrinkPotion();
        A.ServerCoopDrinkPotion();
        if (!Check(A.bCoopPotionPending && Potion.nCount == 2, "duplicate drink request starts one pending operation")) return;
        Next(7, 5);
        break;
    case 7:
        if (!Check(!A.bCoopPotionPending && A.GetHealthCount() == 100 && Potion.nCount == 1,
            "original potion animation commits once on authority")) return;
        A.bAutoQuaff = True;
        A.SetHealth(5);
        A.TakeDamage(10, None, A.Location, vect(0,0,0), 'Probe');
        if (!Check(A.bCoopPotionPending && A.GetHealthCount() == 1 && !A.bCoopDead,
            "original automatic potion retains one health while pending")) return;
        Next(8, 5);
        break;
    case 8:
        if (!Check(!A.bCoopPotionPending && A.GetHealthCount() == 100 && Potion.nCount == 0,
            "automatic potion completes once")) return;
        A.SetHealth(50);
        Potion.SetCount(1);
        A.ServerCoopDrinkPotion();
        A.HarryAnimChannel.GotoState('stateIdle');
        if (!Check(!A.bCoopPotionPending && A.GetHealthCount() == 100 && Potion.nCount == 0,
            "original interrupted potion EndState commits once")) return;
        Next(9, 0.5);
        break;
    case 9:
        A.SetHealth(50);
        Potion.SetCount(2);
        A.ServerCoopDrinkPotion();
        A.TakeDamage(1, None, A.Location, vect(0,0,0), 'pit');
        if (!Check(A.bCoopDead && A.GetHealthCount() == 0 && !A.bCoopPotionPending
            && Potion.nCount == 2, "pit death cancels pending potion without consuming it")) return;
        Next(10, 10);
        break;
    case 10:
        if (A.bCoopDead)
        {
            Finish("BLOCKED", "first-recovery state=" $ A.GetStateName()
                $ " death-animation-finished=" $ A.bCoopDeathAnimFinished
                $ " partner-physics=" $ B.Physics $ " partner-base=" $ B.Base);
            return;
        }
        if (!Check(!A.bCoopAwaitResume && A.GetHealthCount() == 41 && B.GetHealthCount() == 100
            && A.IsInState('PlayerWalking'), "first owner recovered near partner and acknowledged resume")) return;
        B.TakeDamage(100, None, B.Location, vect(0,0,0), 'Probe');
        if (!Check(B.bCoopDead && B.GetHealthCount() == 0 && !B.bInstantDeath,
            "second owner enters original faint presentation")) return;
        Next(11, 10);
        break;
    case 11:
        if (B.bCoopDead)
        {
            Finish("BLOCKED", "second-recovery state=" $ B.GetStateName()
                $ " death-animation-finished=" $ B.bCoopDeathAnimFinished
                $ " partner-physics=" $ A.Physics $ " partner-base=" $ A.Base);
            return;
        }
        if (!Check(!B.bCoopAwaitResume && B.GetHealthCount() == 41 && A.GetHealthCount() == 41,
            "second owner recovered independently")) return;
        A.TakeDamage(1, None, A.Location, vect(0,0,0), 'pit');
        B.TakeDamage(1, None, B.Location, vect(0,0,0), 'pit');
        if (!Check(A.bCoopDead && B.bCoopDead && Game.bCoopRecoveryBlocked,
            "all-dead explicitly blocks; no unsupported native reload")) return;
        Next(12, 2);
        break;
    case 12:
        if (!Check(A.bCoopDead && B.bCoopDead && Game.bCoopRecoveryBlocked,
            "all-dead remains blocked with live connections")) return;
        Finish("PASS", "authority checks complete; visual/input/network-loss/checkpoint gameplay NOT PROVEN");
        break;
    }
}

defaultproperties
{
    RemoteRole=ROLE_None
    bHidden=True
}
