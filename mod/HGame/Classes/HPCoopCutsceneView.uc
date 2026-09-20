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

// Local render interpolation only; the original camera and script keep their
// server clock. Never interpolate a new scene from the previous scene's view.
var bool bPresentationReady;
var int PresentedScene, PresentedSnapshot;
var float ReceivedAt, BlendDuration;
var vector BlendStartPosition, BlendEndPosition;
var rotator BlendStartRotation, BlendEndRotation;
var float BlendStartFOV, BlendEndFOV;

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

simulated function GetCoopView(out vector Position, out rotator Facing, out float FOV)
{
    local float Alpha;
    local rotator Delta;
    if (!bPresentationReady || Role == ROLE_Authority || PresentedScene != SceneSerial)
    {
        bPresentationReady = True;
        PresentedScene = SceneSerial;
        PresentedSnapshot = SnapshotSerial;
        ReceivedAt = Level.TimeSeconds;
        BlendDuration = 0;
        BlendStartPosition = CameraPosition;
        BlendEndPosition = CameraPosition;
        BlendStartRotation = CameraRotation;
        BlendEndRotation = CameraRotation;
        BlendStartFOV = CameraFOV;
        BlendEndFOV = CameraFOV;
    }
    Alpha = 1;
    if (BlendDuration > 0)
        Alpha = FClamp((Level.TimeSeconds - ReceivedAt) / BlendDuration, 0, 1);
    Position = BlendStartPosition + (BlendEndPosition - BlendStartPosition) * Alpha;
    Delta = Normalize(BlendEndRotation - BlendStartRotation);
    Facing = BlendStartRotation + Delta * Alpha;
    FOV = BlendStartFOV + (BlendEndFOV - BlendStartFOV) * Alpha;
    if (PresentedSnapshot == SnapshotSerial) return;

    // Continue from the currently rendered point, so uneven packet arrival
    // cannot pull the camera backwards. Bound added latency to 80 ms.
    BlendDuration = FClamp(Level.TimeSeconds - ReceivedAt, 0.016, 0.08);
    ReceivedAt = Level.TimeSeconds;
    PresentedSnapshot = SnapshotSerial;
    Delta = Normalize(CameraRotation - BlendEndRotation);
    // Preserve abrupt authored camera cuts instead of flying through walls.
    if (VSize(CameraPosition - BlendEndPosition) > 256
        || Abs(Delta.Yaw) > 16384 || Abs(Delta.Pitch) > 16384)
    {
        Position = CameraPosition;
        Facing = CameraRotation;
        FOV = CameraFOV;
        BlendDuration = 0;
    }
    BlendStartPosition = Position;
    BlendStartRotation = Facing;
    BlendStartFOV = FOV;
    BlendEndPosition = CameraPosition;
    BlendEndRotation = CameraRotation;
    BlendEndFOV = CameraFOV;
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
    NetPriority=3
    CameraFOV=90
}
