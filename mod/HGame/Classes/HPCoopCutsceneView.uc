// Shared presentation snapshot. The original server camera owns the cutscene.
// This actor never issues script commands or changes a player's input/state.
class HPCoopCutsceneView extends Actor;

var vector CameraPosition;
var rotator CameraRotation;
var float CameraFOV;
var bool bCaptured;
var int SceneSerial;
var int SnapshotSerial;

// Authority-only sources; clients consume the explicit snapshots above.
var BaseCam SourceCamera;
var HPCoopHarry SourceCanonical;

replication
{
    reliable if (Role == ROLE_Authority)
        CameraPosition, CameraRotation, CameraFOV,
        bCaptured, SceneSerial, SnapshotSerial;
}

function UpdateCoopSnapshot()
{
    if (Role != ROLE_Authority || !bCaptured)
        return;
    if (SourceCamera == None || SourceCamera.bDeleteMe)
    {
        // Keep the session's capture flag; only its coordinator can release it.
        // A missing source is not a valid camera at the world origin.
        SnapshotSerial = 0;
        return;
    }

    CameraPosition = SourceCamera.Location;
    CameraRotation = SourceCamera.Rotation;
    CameraFOV = Default.CameraFOV;
    if (SourceCanonical != None && !SourceCanonical.bDeleteMe
        && SourceCanonical.FOVAngle > 0 && SourceCanonical.FOVAngle < 180)
        CameraFOV = SourceCanonical.FOVAngle;

    SnapshotSerial++;
    if (SnapshotSerial <= 0)
        SnapshotSerial = 1;
}

function SetCoopCapture(bool bCapture, BaseCam Source, HPCoopHarry Canonical)
{
    if (Role != ROLE_Authority)
        return;

    if (!bCapture)
    {
        bCaptured = False;
        SourceCamera = None;
        SourceCanonical = None;
        TickParent = None;
        return;
    }

    if (!bCaptured)
    {
        SceneSerial++;
        if (SceneSerial <= 0)
            SceneSerial = 1;
        SnapshotSerial = 0;
    }
    SourceCamera = Source;
    SourceCanonical = Canonical;
    // Sample after the original camera's controller/cutscript dependencies.
    TickParent = SourceCamera;
    bCaptured = True;
    UpdateCoopSnapshot();
}

simulated function bool HasCoopView()
{
    // Consumers must keep their normal camera until the first valid snapshot.
    return bCaptured && SnapshotSerial > 0;
}

event Tick(float DeltaTime)
{
    if (Role == ROLE_Authority && bCaptured)
        UpdateCoopSnapshot();
}

defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
    bNetTemporary=False
    bHidden=True
    DrawType=DT_None
    Physics=PHYS_None
    bCollideActors=False
    bCollideWorld=False
    bBlockActors=False
    bBlockPlayers=False
    NetUpdateFrequency=30
    CameraFOV=90
}
