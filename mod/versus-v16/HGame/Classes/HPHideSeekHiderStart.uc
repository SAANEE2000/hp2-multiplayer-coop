// Round placement marker only. Login/spawn still uses HPVersusStart.
class HPHideSeekHiderStart extends NavigationPoint;

var() byte HiderIndex;

defaultproperties
{
    bStatic=False
    bNoDelete=False
    bCollideWhenPlacing=True
    HiderIndex=0
}
