// Disposable authority fixture: two real original crab instances run their
// own Tick/state/shot code against separate live owners. No direct AI calls.
class HPCoopAICombatProbe extends Info;

var HPCoopGame Game;
var HPCoopHarry Owners[2];
var firecrabSmall Crabs[2];
var bool bStarted;
var byte TargetSeen[2], AttackSeen[2], ThrowSeen[2], OwnHitSeen[2];
var name LastState[2];
var float Deadline, ObserveUntil;

event PostBeginPlay()
{
    Super.PostBeginPlay();
    Game = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || Level.NetMode != NM_DedicatedServer
        || Game == None || !(Game.RuntimeProbe ~= "AICombat")
        || !(Game.TestStage ~= "RictusempraLessonComplete"))
    {
        Destroy();
        return;
    }
    Deadline = Level.TimeSeconds + 160;
    SetTimer(0.1, True);
    Log("[MP_AI_COMBAT] armed fixture=True input-test=False visual-test=False");
}

function Finish(string Result, string Detail)
{
    local byte I;
    Log("[MP_AI_COMBAT] result=" $ Result $ " detail=" $ Detail
        $ " natural-navigation=False two-pc=False");
    SetTimer(0, False);
    // Remove only the two enemies created by this disposable fixture.
    for (I = 0; I < 2; I++)
        if (Crabs[I] != None && !Crabs[I].bDeleteMe) Crabs[I].Destroy();
    Destroy();
}

function ActualHit(spellFireSmall Shot, HPCoopHarry Victim,
    int BeforeHealth, int AfterHealth)
{
    local byte I;
    if (!bStarted || Shot == None || Victim == None
        || AfterHealth >= BeforeHealth) return;
    for (I = 0; I < 2; I++)
        if (Crabs[I] != None && Shot.Owner == Crabs[I]
            && Shot.Instigator == Crabs[I] && Owners[I] == Victim)
        {
            OwnHitSeen[I] = 1;
            Log("[MP_AI_COMBAT] real-hit slot=" $ I $ " projectile=" $ Shot
                $ " caster=" $ Crabs[I] $ " victim=" $ Victim
                $ " intended=" $ Shot.TargetActor
                $ " health=" $ BeforeHealth $ "->" $ AfterHealth);
            return;
        }
    Log("[MP_AI_COMBAT] cross-hit projectile=" $ Shot $ " victim=" $ Victim
        $ " health=" $ BeforeHealth $ "->" $ AfterHealth);
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
    Owners[0] = A;
    Owners[1] = B;
    return True;
}

event Timer()
{
    local byte I;
    local vector Gap, Position;
    if (!bStarted)
    {
        if (Level.TimeSeconds > Deadline)
        {
            Finish("BLOCKED", "pair-or-intro-not-released");
            return;
        }
        if (!PairReleased()) return;
        Gap = Owners[1].Location - Owners[0].Location;
        if (VSize2d(Gap) < 350 || VSize2d(Gap) > 850
            || Abs(Gap.Z) > 60 || !Game.IsAIPlayerAvailable(Owners[0])
            || !Game.IsAIPlayerAvailable(Owners[1]))
        {
            Finish("BLOCKED", "owner-separation-or-availability");
            return;
        }
        for (I = 0; I < 2; I++)
        {
            if (I == 0) Position = Owners[0].Location + Gap * 0.3;
            else Position = Owners[1].Location - Gap * 0.3;
            Crabs[I] = Spawn(Class'firecrabSmall', self,, Position,
                rotator(Owners[I].Location - Position));
            if (Crabs[I] == None)
            {
                Finish("BLOCKED", "original-crab-spawn-refused-slot-" $ I);
                return;
            }
            Log("[MP_AI_COMBAT] spawned slot=" $ I $ " enemy=" $ Crabs[I]
                $ " state=" $ Crabs[I].GetStateName() $ " current="
                $ Crabs[I].bInCurrentGameState $ " distance="
                $ VSize(Crabs[I].Location - Owners[I].Location)
                $ " los=" $ Crabs[I].LineOfSightTo(Owners[I]));
            if (!Game.IsCh1CombatOpen(Crabs[I])
                || !Crabs[I].LineOfSightTo(Owners[I]))
            {
                Finish("BLOCKED", "original-crab-context-slot-" $ I);
                return;
            }
            LastState[I] = Crabs[I].GetStateName();
        }
        bStarted = True;
        ObserveUntil = Level.TimeSeconds + 20;
        return;
    }
    for (I = 0; I < 2; I++)
    {
        if (Crabs[I] == None || Crabs[I].bDeleteMe || Owners[I] == None)
        {
            Finish("BLOCKED", "actor-disappeared-slot-" $ I);
            return;
        }
        if (Crabs[I].CoopCombatTarget == Owners[I]) TargetSeen[I] = 1;
        if (Crabs[I].IsInState('AttackHarry')) AttackSeen[I] = 1;
        if (Crabs[I].IsInState('throwing')) ThrowSeen[I] = 1;
        if (Crabs[I].GetStateName() != LastState[I])
        {
            LastState[I] = Crabs[I].GetStateName();
            Log("[MP_AI_COMBAT] transition slot=" $ I $ " state=" $ LastState[I]
                $ " target=" $ Crabs[I].CoopCombatTarget
                $ " own-health=" $ Owners[I].GetHealthCount());
        }
    }
    if (TargetSeen[0] != 0 && TargetSeen[1] != 0
        && AttackSeen[0] != 0 && AttackSeen[1] != 0
        && OwnHitSeen[0] != 0 && OwnHitSeen[1] != 0)
    {
        Finish("PASS_OWN_HITS", "two-original-attacks-and-owned-projectile-damage");
        return;
    }
    if (Level.TimeSeconds >= ObserveUntil)
        Finish("BLOCKED", "target0=" $ TargetSeen[0] $ " target1=" $ TargetSeen[1]
            $ " attack0=" $ AttackSeen[0] $ " attack1=" $ AttackSeen[1]
            $ " throw0=" $ ThrowSeen[0] $ " throw1=" $ ThrowSeen[1]
            $ " hit0=" $ OwnHitSeen[0] $ " hit1=" $ OwnHitSeen[1]);
}

defaultproperties
{
    RemoteRole=ROLE_None
    bHidden=True
    Physics=PHYS_None
    bCollideActors=False
    bCollideWorld=False
}
