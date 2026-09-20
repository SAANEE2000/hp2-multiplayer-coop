// Disposable authority fixture: two original orange snails run their own
// patrol, ram, collision and body-damage code against separate ready owners.
class HPCoopAISnailProbe extends Info;

var HPCoopGame Game;
var HPCoopHarry Owners[2];
var orangesnail Snails[2];
var byte TargetSeen[2], RamSeen[2], BodyHitSeen[2];
var name LastState[2];
var bool bStarted;
var float Deadline, ObserveUntil;

event PostBeginPlay()
{
    Super.PostBeginPlay();
    Game = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || Level.NetMode != NM_DedicatedServer
        || Game == None || !(Game.RuntimeProbe ~= "AISnail")
        || !(Game.TestStage ~= "RictusempraLessonComplete"))
    { Destroy(); return; }
    Deadline = Level.TimeSeconds + 160;
    SetTimer(0.1, True);
    Log("[MP_AI_SNAIL] armed fixture=True direct-ai-call=False visual-test=False");
}

function Finish(string Result, string Detail)
{
    local byte I;
    Log("[MP_AI_SNAIL] result=" $ Result $ " detail=" $ Detail
        $ " natural-navigation=False trail-hit=False two-pc=False");
    SetTimer(0, False);
    for (I = 0; I < 2; I++)
        if (Snails[I] != None && !Snails[I].bDeleteMe)
        {
            Snails[I].EndTrail();
            Snails[I].Destroy();
        }
    Destroy();
}

function ActualHit(HPCoopHarry Victim, Pawn Attacker, name DamageType,
    int BeforeHealth, int AfterHealth)
{
    local byte I;
    if (!bStarted || Victim == None || Attacker == None
        || DamageType != 'Snail' || AfterHealth >= BeforeHealth) return;
    for (I = 0; I < 2; I++)
        if (Snails[I] == Attacker && Owners[I] == Victim)
        {
            BodyHitSeen[I] = 1;
            Log("[MP_AI_SNAIL] real-body-hit slot=" $ I
                $ " snail=" $ Attacker $ " victim=" $ Victim
                $ " health=" $ BeforeHealth $ "->" $ AfterHealth);
            return;
        }
    Log("[MP_AI_SNAIL] cross-body-hit snail=" $ Attacker
        $ " victim=" $ Victim $ " health=" $ BeforeHealth
        $ "->" $ AfterHealth);
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
    if (Game.IntroCoordinator != None && Game.IntroCoordinator.Phase != 5)
        return False;
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
        { Finish("BLOCKED", "pair-or-intro-not-released"); return; }
        if (!PairReleased()) return;
        Gap = Owners[1].Location - Owners[0].Location;
        if (VSize2d(Gap) < 350 || VSize2d(Gap) > 850
            || Abs(Gap.Z) > 60 || !Game.IsAIPlayerAvailable(Owners[0])
            || !Game.IsAIPlayerAvailable(Owners[1]))
        { Finish("BLOCKED", "owner-separation-or-availability"); return; }
        for (I = 0; I < 2; I++)
        {
            if (I == 0) Position = Owners[0].Location + Gap * 0.25;
            else Position = Owners[1].Location - Gap * 0.25;
            Snails[I] = Spawn(Class'orangesnail', self,, Position,
                rotator(Owners[I].Location - Position));
            if (Snails[I] == None)
            { Finish("BLOCKED", "original-snail-spawn-slot-" $ I); return; }
            // A dynamic snail has no authored PatrolPoint. Use the original
            // no-route PATH_SEARCH patrol loop so its normal Tick can acquire
            // an owner; this is an explicit fixture configuration.
            Snails[I].ePatrolType = PATROLTYPE_PATH_SEARCH;
            Log("[MP_AI_SNAIL] spawned slot=" $ I $ " enemy=" $ Snails[I]
                $ " state=" $ Snails[I].GetStateName() $ " current="
                $ Snails[I].bInCurrentGameState $ " distance="
                $ VSize(Snails[I].Location - Owners[I].Location)
                $ " can-see=" $ Snails[I].CanSee(Owners[I])
                $ " patrol-type=" $ Snails[I].ePatrolType);
            if (!Game.IsCh1CombatOpen(Snails[I])
                || !Snails[I].CanSee(Owners[I]))
            { Finish("BLOCKED", "original-snail-context-slot-" $ I); return; }
            LastState[I] = Snails[I].GetStateName();
        }
        bStarted = True;
        ObserveUntil = Level.TimeSeconds + 22;
        return;
    }
    for (I = 0; I < 2; I++)
    {
        if (Snails[I] == None || Snails[I].bDeleteMe || Owners[I] == None)
        { Finish("BLOCKED", "actor-disappeared-slot-" $ I); return; }
        if (Snails[I].CoopCombatTarget == Owners[I]) TargetSeen[I] = 1;
        if (Snails[I].IsInState('RamHarry')) RamSeen[I] = 1;
        if (Snails[I].GetStateName() != LastState[I])
        {
            LastState[I] = Snails[I].GetStateName();
            Log("[MP_AI_SNAIL] transition slot=" $ I $ " state=" $ LastState[I]
                $ " target=" $ Snails[I].CoopCombatTarget
                $ " location=" $ Snails[I].Location
                $ " own-health=" $ Owners[I].GetHealthCount());
        }
    }
    if (TargetSeen[0] != 0 && TargetSeen[1] != 0
        && RamSeen[0] != 0 && RamSeen[1] != 0
        && BodyHitSeen[0] != 0 && BodyHitSeen[1] != 0)
    { Finish("PASS_OWN_BODY_HITS", "two-original-rams-and-matched-contact-damage"); return; }
    if (Level.TimeSeconds >= ObserveUntil)
        Finish("BLOCKED", "target0=" $ TargetSeen[0] $ " target1=" $ TargetSeen[1]
            $ " ram0=" $ RamSeen[0] $ " ram1=" $ RamSeen[1]
            $ " hit0=" $ BodyHitSeen[0] $ " hit1=" $ BodyHitSeen[1]);
}

defaultproperties
{
    RemoteRole=ROLE_None
    bHidden=True
    Physics=PHYS_None
    bCollideActors=False
    bCollideWorld=False
}
