// Per-connection co-op identity; spawned by Pawn before GameInfo.Login uses it.
class HPCoopPRI extends PlayerReplicationInfo;

var byte CoopSlot;
var bool bStoryLeader;

replication
{
    reliable if (Role == ROLE_Authority)
        CoopSlot, bStoryLeader;
}

defaultproperties
{
    CoopSlot=255
}
