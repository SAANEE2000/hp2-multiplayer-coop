// Network adapter around the original SpongifyPad trajectory. Activation,
// touch ownership and the ballistic endpoint are decided by authority. The
// client receives state/velocity for presentation and normal correction.
class HPVersusSpongifyPad extends SpongifyPad;

var bool bVersusEnabled;
var float VersusEnabledUntil;
var vector VersusTargetLocation;
var bool bLastVisualEnabled;

replication
{
    reliable if (Role == ROLE_Authority)
        bVersusEnabled, VersusEnabledUntil, VersusTargetLocation;
}

function PreBeginPlay()
{
    // Skip SpongifyPad's Level.PlayerHarryActor cache and event lookup. The
    // arena assigns Target explicitly after spawning this server actor.
    Super(HProp).PreBeginPlay();
    vStartPosition = Location;
    SetCollision(True, False, False);
    bVersusEnabled = False;
    bLastVisualEnabled = True;
    SyncVersusPadVisual();
}

simulated event PostNetReceive()
{
    SyncVersusPadVisual();
}

simulated function SyncVersusPadVisual()
{
    if (bLastVisualEnabled == bVersusEnabled)
        return;

    bLastVisualEnabled = bVersusEnabled;
    bHidden = !bVersusEnabled;
    if (Level.NetMode == NM_DedicatedServer)
        return;

    if (bVersusEnabled)
        TurnOnSpecialFX();
    else
        TurnOffSpecialFX();
}

function bool IsEnabled()
{
    return bVersusEnabled;
}

function bool HandleSpellSpongify(optional baseSpell spell,
    optional Vector vHitLocation)
{
    if (Role != ROLE_Authority)
        return False;

    bVersusEnabled = True;
    VersusEnabledUntil = Level.TimeSeconds + fTimeEnabled;
    if (Target != None)
        VersusTargetLocation = Target.Location;
    SyncVersusPadVisual();
    Log("HPVersusSpongifyPad activated pad=" $ string(self)
        $ " target=" $ string(Target)
        $ " until=" $ string(VersusEnabledUntil));
    return True;
}

function DisableVersusPad(string Reason)
{
    if (Role != ROLE_Authority)
        return;
    bVersusEnabled = False;
    VersusEnabledUntil = 0.0;
    SyncVersusPadVisual();
    Log("HPVersusSpongifyPad disabled pad=" $ string(self)
        $ " reason=" $ Reason);
}

function OnBounce(Actor Other)
{
    local HPVersusHarry H;
    local vector Trajectory;

    if (Role != ROLE_Authority || !bVersusEnabled)
        return;

    H = HPVersusHarry(Other);
    if (H == None || H.bVersusDead)
        return;

    if (Target != None)
    {
        VersusTargetLocation = Target.Location;
        Trajectory = ComputeTrajectoryByTime(
            Location, VersusTargetLocation, fTimeToHitTarget);
    }
    else
        Trajectory = PadDir * PadSpeed;

    H.BeginVersusSpongify(self, Trajectory, VersusTargetLocation);
    bBouncing = True;
    if (fxSheet != None)
        fxSheet.DrawScale = fxSheet.Default.DrawScale * 2.0;
    PlaySound(Sound'SPN_bounce_on', SLOT_None,, True);
    Log("HPVersusSpongifyPad bounce pad=" $ string(self)
        $ " pawn=" $ string(H)
        $ " velocity=" $ string(Trajectory)
        $ " target=" $ string(VersusTargetLocation));
}

simulated event Tick(float DeltaTime)
{
    if (Role == ROLE_Authority && bVersusEnabled
        && VersusEnabledUntil > 0.0
        && Level.TimeSeconds >= VersusEnabledUntil)
        DisableVersusPad("Expired");

    SyncVersusPadVisual();
    if (Level.NetMode != NM_DedicatedServer && bVersusEnabled
        && fxSparkles != None && fxSheet != None)
        UpdateSpecialFX(DeltaTime);
}

// SpongifyPad's inherited stateDisabled has its own HandleSpellSpongify and
// therefore outranks a derived global override. Keep this adapter in one
// neutral state so every hit reaches the authoritative function above.
auto state VersusPadState
{
}

defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
    bNetNotify=True
    bVersusEnabled=False
    bLastVisualEnabled=True
}
