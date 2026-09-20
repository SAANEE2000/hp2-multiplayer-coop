// Local read-only witness for the explicit pickup replication fixture.
// Never hides, destroys or changes the observed gameplay actor.
class HPCoopPickupObserver extends Info;

var HPCoopHarry LocalPlayer;
var HProp Subject;
var name SubjectName;
var Class<HProp> SubjectClass;
var int Serial;
var byte Stage;
var float Deadline, LateUntil;

function Observe(HPCoopHarry H, int NewSerial, HProp P)
{
    if (Level.NetMode != NM_Client || H == None || Owner != H
        || !H.IsLocalCoopPlayer() || NewSerial <= 0 || P == None
        || P.bDeleteMe || P.bHidden || P.Role != ROLE_SimulatedProxy
        || !P.bCollideActors || (P.Class != Class'ChocolateFrog'
            && P.Class != Class'WWellBlueBottle')) return;
    if (Serial == NewSerial) return;
    if (Stage != 0 && Stage != 3) return;
    LocalPlayer = H;
    Serial = NewSerial;
    Subject = P;
    SubjectName = P.Name;
    SubjectClass = P.Class;
    Stage = 1;
    Deadline = Level.TimeSeconds + 15;
    SetTimer(0.1, True);
    Log("[MP_PROBE] probe=pickup-net stage=seen serial=" $ Serial
        $ " slot=" $ H.CoopSlot $ " local-object=" $ P $ " class=" $ P.Class
        $ " role=" $ P.Role $ " hidden=" $ P.bHidden
        $ " collide=" $ P.bCollideActors $ " location=" $ P.Location);
    H.ServerCoopPickupWitness(Serial, 1, P);
}

function Collected(int NewSerial)
{
    if (Serial != NewSerial || Stage != 1) return;
    Stage = 2;
    Deadline = Level.TimeSeconds + 5;
}

function bool ReplicaExists()
{
    local HProp P;
    if (Subject != None && !Subject.bDeleteMe) return True;
    // The local name was saved AFTER seeing the exact network reference.
    foreach AllActors(Class'HProp', P)
        if (!P.bDeleteMe && P.Name == SubjectName && P.Class == SubjectClass)
            return True;
    return False;
}

event Timer()
{
    if (LocalPlayer == None || !LocalPlayer.IsLocalCoopPlayer())
    {
        Destroy();
        return;
    }
    if (Stage == 1 || Stage == 2)
    {
        if (Level.TimeSeconds > Deadline)
        {
            Log("[MP_PROBE] probe=pickup-net stage=FAIL serial=" $ Serial
                $ " reason=observation-timeout previous-stage=" $ Stage);
            LocalPlayer.ServerCoopPickupWitness(Serial, 4, None);
            SetTimer(0, False);
            return;
        }
        if (Stage == 2 && !ReplicaExists())
        {
            Stage = 3;
            LateUntil = Level.TimeSeconds + 2;
            Log("[MP_PROBE] probe=pickup-net stage=gone serial=" $ Serial
                $ " slot=" $ LocalPlayer.CoopSlot $ " local-name=" $ SubjectName);
            LocalPlayer.ServerCoopPickupWitness(Serial, 2, None);
        }
    }
    else if (Stage == 3)
    {
        if (ReplicaExists())
        {
            Log("[MP_PROBE] probe=pickup-net stage=FAIL serial=" $ Serial
                $ " reason=replica-reappeared");
            LocalPlayer.ServerCoopPickupWitness(Serial, 4, None);
            SetTimer(0, False);
        }
        else if (Level.TimeSeconds >= LateUntil)
        {
            Log("[MP_PROBE] probe=pickup-net stage=late-gone serial=" $ Serial
                $ " slot=" $ LocalPlayer.CoopSlot $ " local-name=" $ SubjectName);
            LocalPlayer.ServerCoopPickupWitness(Serial, 3, None);
            SetTimer(0, False);
        }
    }
}

defaultproperties
{
    RemoteRole=ROLE_None
    bHidden=True
    bCollideActors=False
    bCollideWorld=False
}
