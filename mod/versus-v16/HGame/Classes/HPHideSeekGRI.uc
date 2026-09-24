// Replicated Hide & Seek state layered on the accepted Versus GRI.
class HPHideSeekGRI extends HPVersusGRI;

var name HideSeekPhase;
var int HidersLeft;
var byte HunterSlot;
var string HunterName;

replication
{
    reliable if (Role == ROLE_Authority)
        HideSeekPhase, HidersLeft, HunterSlot, HunterName;
}

defaultproperties
{
    HideSeekPhase=WaitingForPlayers
    HunterSlot=255
}
