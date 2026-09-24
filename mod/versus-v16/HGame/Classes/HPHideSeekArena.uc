// Small functional fixture spawned only on HPV_HideSeek.unr. The underlying
// map remains a copy of the accepted startup arena.
class HPHideSeekArena extends Info;

var vector ArenaCenter;
var HPHideSeekHunterWaitStart WaitStart;
var HPHideSeekHunterSeekStart SeekStart;
var HPHideSeekHiderStart HiderStarts[8];
var HPHideSeekArenaProp Props[6];
var HPVersusArenaBarrier Covers[6];
var bool bArenaReady;

replication
{
    reliable if (Role == ROLE_Authority)
        bArenaReady;
}

function vector Offset(float X, float Y, float Z)
{
    local vector V;
    V = ArenaCenter;
    V.X += X;
    V.Y += Y;
    V.Z += Z;
    return V;
}

function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Role == ROLE_Authority)
        BuildArena();
}

function BuildArena()
{
    local int I;
    local vector P;

    ArenaCenter = Location;
    WaitStart = Spawn(Class'HPHideSeekHunterWaitStart',,,
        Offset(0,-520,0), rot(0,16384,0));
    SeekStart = Spawn(Class'HPHideSeekHunterSeekStart',,,
        Offset(0,-250,0), rot(0,16384,0));

    HiderStarts[0] = Spawn(Class'HPHideSeekHiderStart',,, Offset(-420,-250,0), rot(0,0,0));
    HiderStarts[1] = Spawn(Class'HPHideSeekHiderStart',,, Offset(420,-250,0), rot(0,32768,0));
    HiderStarts[2] = Spawn(Class'HPHideSeekHiderStart',,, Offset(-420,0,0), rot(0,0,0));
    HiderStarts[3] = Spawn(Class'HPHideSeekHiderStart',,, Offset(420,0,0), rot(0,32768,0));
    HiderStarts[4] = Spawn(Class'HPHideSeekHiderStart',,, Offset(-420,250,0), rot(0,0,0));
    HiderStarts[5] = Spawn(Class'HPHideSeekHiderStart',,, Offset(420,250,0), rot(0,32768,0));
    HiderStarts[6] = Spawn(Class'HPHideSeekHiderStart',,, Offset(-180,420,0), rot(0,-16384,0));
    HiderStarts[7] = Spawn(Class'HPHideSeekHiderStart',,, Offset(180,420,0), rot(0,-16384,0));
    for (I = 0; I < 8; I++)
        if (HiderStarts[I] != None)
            HiderStarts[I].HiderIndex = I;

    for (I = 0; I < 6; I++)
    {
        P = Offset(-300 + float(I) * 120, 120, 0);
        Props[I] = Spawn(Class'HPHideSeekArenaProp',,, P, rot(0,0,0));
        if (Props[I] != None)
            Props[I].Configure(I + 1);
    }

    Covers[0] = Spawn(Class'HPVersusArenaBarrier',,, Offset(-230,-80,0), rot(0,0,0));
    Covers[1] = Spawn(Class'HPVersusArenaBarrier',,, Offset(230,-80,0), rot(0,0,0));
    Covers[2] = Spawn(Class'HPVersusArenaBarrier',,, Offset(-230,260,0), rot(0,0,0));
    Covers[3] = Spawn(Class'HPVersusArenaBarrier',,, Offset(230,260,0), rot(0,0,0));
    Covers[4] = Spawn(Class'HPVersusArenaBarrier',,, Offset(-60,360,0), rot(0,0,0));
    Covers[5] = Spawn(Class'HPVersusArenaBarrier',,, Offset(60,-360,0), rot(0,0,0));

    bArenaReady = WaitStart != None && SeekStart != None;
    Log("HPHideSeekArena built ready=" $ string(bArenaReady)
        $ " center=" $ string(ArenaCenter));
}

defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
}
