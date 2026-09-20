// Authoritative special-movement context, separate from native SavedMove replay.
// Consumers decide how to apply it. This actor never moves or changes its pawn.
class HPCoopMovementState extends Actor;

var HPCoopHarry MovementPawn;
var int SceneSerial;
var int SnapshotSerial;
var bool bActive;
var name Phase;
var name MovementState;
var float SnapshotTime;
var float MoveTimeStamp;

var vector PawnPosition;
var vector PawnVelocity;
var rotator PawnRotation;
var EPhysics PawnPhysics;
var Actor PawnBase;
var float CapsuleRadius;
var float CapsuleHeight;
var float CapsuleWidth;
var vector PawnPrePivot;

var name MovementAnimSequence;
var float MovementAnimFrame;
var float MovementAnimRate;
var bool bMovementAnimLoop;
var bool bMovementAnimMove;

var vector MovementDestination;
var vector MountDelta;
var Actor MountBase;
var bool bFallingMount;

// Sampling cadence only; this is not a second movement/physics clock.
var float SnapshotInterval;
var float SnapshotElapsed;

replication
{
    // Do not condition the payload on bActive: the final inactive snapshot and
    // late-channel initial state must retain their complete context.
    reliable if (Role == ROLE_Authority)
        MovementPawn, SceneSerial, SnapshotSerial, bActive, Phase, MovementState,
        SnapshotTime, MoveTimeStamp, PawnPosition, PawnVelocity, PawnRotation,
        PawnPhysics, PawnBase, CapsuleRadius, CapsuleHeight, CapsuleWidth,
        PawnPrePivot, MovementAnimSequence, MovementAnimFrame, MovementAnimRate,
        bMovementAnimLoop, bMovementAnimMove, MovementDestination, MountDelta,
        MountBase, bFallingMount;
}

function bool SamplePawn(optional name PhaseName)
{
    local name PreviousState;

    if (Role != ROLE_Authority || MovementPawn == None || MovementPawn.bDeleteMe)
        return False;

    PreviousState = MovementState;
    MovementState = MovementPawn.GetStateName();
    if (PhaseName != '')
        Phase = PhaseName;
    else if (Phase == '' || PreviousState != MovementState)
        Phase = MovementState;

    PawnPosition = MovementPawn.Location;
    PawnVelocity = MovementPawn.Velocity;
    PawnRotation = MovementPawn.Rotation;
    PawnPhysics = MovementPawn.Physics;
    PawnBase = MovementPawn.Base;
    CapsuleRadius = MovementPawn.CollisionRadius;
    CapsuleHeight = MovementPawn.CollisionHeight;
    CapsuleWidth = MovementPawn.CollisionWidth;
    PawnPrePivot = MovementPawn.PrePivot;

    MovementAnimSequence = MovementPawn.AnimSequence;
    MovementAnimFrame = MovementPawn.AnimFrame;
    MovementAnimRate = MovementPawn.AnimRate;
    bMovementAnimLoop = MovementPawn.bAnimLoop;
    bMovementAnimMove = MovementPawn.bAnimMove;
    MovementDestination = MovementPawn.Destination;
    MountDelta = MovementPawn.MountDelta;
    MountBase = MovementPawn.MountBase;
    bFallingMount = MovementPawn.bFallingMount;

    SnapshotTime = Level.TimeSeconds;
    MoveTimeStamp = MovementPawn.CurrentTimeStamp;
    SnapshotSerial++;
    if (SnapshotSerial <= 0)
        SnapshotSerial = 1;
    return True;
}

function BeginSnapshot(HPCoopHarry P, optional name PhaseName)
{
    if (Role != ROLE_Authority || P == None || P.bDeleteMe
        || P.Role != ROLE_Authority || (Owner != None && Owner != P))
        return;

    // One helper belongs to one pawn. Repeated begin within an active operation
    // refreshes its phase instead of restarting its generation/collision logic.
    if (Owner == None)
        SetOwner(P);
    MovementPawn = P;
    if (!bActive)
    {
        SceneSerial++;
        if (SceneSerial <= 0)
            SceneSerial = 1;
        SnapshotSerial = 0;
        Phase = '';
    }
    bActive = True;
    SnapshotElapsed = 0;
    SamplePawn(PhaseName);
}

function UpdateSnapshot(optional name PhaseName)
{
    if (Role != ROLE_Authority || !bActive)
        return;
    SnapshotElapsed = 0;
    if (!SamplePawn(PhaseName))
    {
        // Preserve the last valid pose if the source has gone away. An inactive
        // snapshot does not grant a destroyed/replaced pawn permission to move.
        bActive = False;
    }
}

function EndSnapshot(optional name FinalPhase)
{
    if (Role != ROLE_Authority || !bActive)
        return;
    // Integration must call this after the original state's final movement and
    // collision/PrePivot restoration. No restoration is performed here.
    SamplePawn(FinalPhase);
    if (FinalPhase != '')
        Phase = FinalPhase;
    bActive = False;
    SnapshotElapsed = 0;
}

simulated function bool HasSnapshot()
{
    // Also true for a valid final snapshot; consumers compare both serials.
    return MovementPawn != None && SceneSerial > 0 && SnapshotSerial > 0;
}

simulated function bool HasActiveSnapshot()
{
    return bActive && HasSnapshot();
}

event Tick(float DeltaTime)
{
    if (Role != ROLE_Authority || !bActive)
        return;
    SnapshotElapsed += DeltaTime;
    if (SnapshotElapsed >= SnapshotInterval)
        UpdateSnapshot();
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
    SnapshotInterval=0.03333333
}
