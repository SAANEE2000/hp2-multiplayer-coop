// Original native-contact fixture plus real client replica witnesses.
// Item relevance, RemoteRole, ownership and collision defaults stay intact.
class HPCoopPickupNetProbe extends HPCoopPickupProbe;

var byte WitnessStage[2];
var int WitnessSerial;
var float NextObserve;
var string SubjectDescription;
var byte SubjectSlot;
var bool bSubjectPotion;

function string ProbeOption() { return "PickupNet"; }

function bool PrepareSubject(byte Slot, bool bPotion)
{
    local HProp P;
    local vector Start;
    P = CreateFixtureProp(Slot, bPotion, Start);
    if (P == None) return False;
    ActivePickup = P;
    OriginalPickupContext = P.PlayerHarry;
    SubjectDescription = string(P);
    SubjectSlot = Slot;
    bSubjectPotion = bPotion;
    WitnessStage[0] = 0;
    WitnessStage[1] = 0;
    WitnessSerial++;
    Phase = 1;
    Deadline = Level.TimeSeconds + 15;
    NextObserve = 0;
    Log("[MP_PROBE] probe=pickup-net stage=waiting-for-replicas serial=" $ WitnessSerial
        $ " subject=" $ P $ " role=" $ P.Role $ " remote=" $ P.RemoteRole
        $ " always-relevant=" $ P.bAlwaysRelevant $ " location=" $ P.Location);
    return True;
}

function ReportWitness(HPCoopHarry H, int Serial, byte Result, HProp Seen)
{
    local byte I;
    if (!bArmed || bFinished || Serial != WitnessSerial || !HasReadyPair()) return;
    for (I = 0; I < 2; I++)
        if (Players[I] == H)
        {
            if (Result == 4)
            {
                Finish("FAIL", "client-replica-observer-failed");
                return;
            }
            if (Result == 1 && Phase == 1 && Seen == ActivePickup
                && Seen != None && !Seen.bDeleteMe && WitnessStage[I] == 0)
                WitnessStage[I] = 1;
            else if (Result == 2 && Phase == 2 && WitnessStage[I] == 1)
                WitnessStage[I] = 2;
            else if (Result == 3 && Phase == 2 && WitnessStage[I] == 2)
                WitnessStage[I] = 3;
            else return;
            Log("[MP_PROBE] probe=pickup-net witness=" $ Result $ " slot=" $ I
                $ " serial=" $ Serial $ " subject=" $ SubjectDescription);
            return;
        }
}

event Timer()
{
    local byte I;
    local HProp P;
    if (!bArmed || bFinished) return;
    if (!bPairReadySeen)
    {
        if (!HasReadyPair()) return;
        bPairReadySeen = True;
        Deadline = Level.TimeSeconds + 180;
    }
    if (Level.TimeSeconds > Deadline)
    {
        Finish("BLOCKED", "replica-fixture-timeout");
        return;
    }
    if (Phase == 0)
    {
        if (Game.bStoryCaptured) { bSawIntro = True; return; }
        if (!bSawIntro || Game.StoryView == None || Game.StoryView.SceneSerial < 1) return;
        if (!SeedFixture()) return;
        if (!PrepareSubject(1, False))
        {
            Finish("BLOCKED", "no-safe-native-contact-path");
            return;
        }
    }
    if (!StablePlayers() || !CountsMatch())
    {
        Finish("BLOCKED", "fixture-player-or-status-changed");
        return;
    }
    if (Phase == 1)
    {
        if (ActivePickup == None || ActivePickup.bDeleteMe || ActivePickup.bHidden)
        {
            Finish("FAIL", "item-consumed-before-both-replica-witnesses");
            return;
        }
        if (WitnessStage[0] == 1 && WitnessStage[1] == 1)
        {
            StepEvents = 0;
            bEventContractOK = True;
            if (bSubjectPotion) ExpectedPotions[SubjectSlot]++;
            else ExpectedHealth[SubjectSlot] = Min(100, ExpectedHealth[SubjectSlot] + 40);
            P = ActivePickup;
            P.MoveSmooth(Players[SubjectSlot].Location - P.Location);
            if (StepEvents != 1 || !bEventContractOK || !CountsMatch()
                || (P != None && (!P.bDeleteMe || !P.bCoopPickupClaimed)))
            {
                Finish("FAIL", "native-contact-award-or-destruction-contract");
                return;
            }
            ActivePickup = None;
            Phase = 2;
            Deadline = Level.TimeSeconds + 10;
            Log("[MP_PROBE] probe=pickup-net stage=server-collected serial=" $ WitnessSerial
                $ " events=" $ StepEvents $ " subject=" $ SubjectDescription);
            for (I = 0; I < 2; I++) Players[I].ClientCoopPickupCollected(WitnessSerial);
        }
        else if (Level.TimeSeconds >= NextObserve)
        {
            NextObserve = Level.TimeSeconds + 0.5;
            for (I = 0; I < 2; I++)
                if (WitnessStage[I] == 0)
                    Players[I].ClientCoopPickupObserve(WitnessSerial, ActivePickup);
        }
    }
    else if (Phase == 2 && WitnessStage[0] == 3 && WitnessStage[1] == 3)
    {
        if (WitnessSerial == 1)
        {
            Log("[MP_PROBE] probe=pickup-net check=PASS serial=1 class=ChocolateFrog both-late-gone=True");
            if (!PrepareSubject(0, True)) Finish("BLOCKED", "no-safe-bottle-contact-path");
            return;
        }
        Log("[MP_PROBE] probe=pickup-net status=PASS serial=" $ WitnessSerial
            $ " replica-lifetime=True original-native-touch=True events=" $ TotalEvents
            $ " relevance-override=False client-hide=False placed-map=False visual=False two-pc=False");
        Finish("PASS", "original-class-replica-lifetime-only; discard-fixture-session");
    }
}
