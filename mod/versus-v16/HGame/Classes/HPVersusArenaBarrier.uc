// Thin replicated presentation target for the stock TriggerEvent chain.
class HPVersusArenaBarrier extends HProp;

var bool bOpened;
var vector ClosedLocation;
var() vector OpenOffset;
var bool bLastPresentedOpen;

replication
{
    reliable if (Role == ROLE_Authority)
        bOpened, ClosedLocation, OpenOffset;
}

function PostBeginPlay()
{
    Super.PostBeginPlay();
    ClosedLocation = Location;
    bLastPresentedOpen = !bOpened;
    PresentBarrier();
}

simulated event PostNetReceive()
{
    PresentBarrier();
}

simulated function PresentBarrier()
{
    if (bLastPresentedOpen == bOpened)
        return;
    bLastPresentedOpen = bOpened;
    if (bOpened)
    {
        SetLocation(ClosedLocation + OpenOffset);
        SetCollision(False, False, False);
    }
    else
    {
        SetLocation(ClosedLocation);
        SetCollision(True, True, True);
    }
    if (Role < ROLE_Authority)
        Log("HPVersusWorldClient barrier=" $ string(self)
            $ " opened=" $ string(bOpened)
            $ " location=" $ string(Location));
}

function Trigger(Actor Other, Pawn EventInstigator)
{
    if (Role != ROLE_Authority || bOpened)
        return;
    bOpened = True;
    PresentBarrier();
    Log("HPVersusArenaBarrier opened barrier=" $ string(self)
        $ " other=" $ string(Other));
}

defaultproperties
{
    OpenOffset=(X=0.0,Y=0.0,Z=150.0)
    DrawType=DT_Mesh
    Mesh=SkeletalMesh'HPModels.skboulderMesh'
    DrawScale=1.25
    CollisionRadius=55.0
    CollisionHeight=55.0
    bCollideActors=True
    bCollideWorld=False
    bBlockActors=True
    bBlockPlayers=True
    bProjTarget=False
    bStatic=False
    bNoDelete=False
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
    bNetNotify=True
}
