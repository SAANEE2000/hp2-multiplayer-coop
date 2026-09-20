// Replicated session identity. Story progression is not a per-client authority.
class HPCoopGRI extends GameReplicationInfo;

var HPCoopHarry StoryLeader;
var byte ConnectedPlayers;
var bool bStoryCaptured;
var string SharedGameState;

replication
{
    reliable if (Role == ROLE_Authority)
        StoryLeader, ConnectedPlayers, bStoryCaptured, SharedGameState;
}
