// Observer-only upper-body presentation. This channel never invokes Cast(),
// changes movement, or owns spell authority.
class HPVersusRemoteAnimChannel extends AnimChannel;

var Mesh ConfiguredMesh;
var name CastGesture;

simulated function ConfigureForMesh(Mesh CandidateMesh)
{
    local Animation GestureSet;

    if (CandidateMesh == None || CandidateMesh == ConfiguredMesh)
        return;

    GestureSet = class'HPVersusCharacterProfiles'.static.GetCastGestureSet(
        CandidateMesh);
    CastGesture = class'HPVersusCharacterProfiles'.static.GetCastGesture(
        CandidateMesh);
    if (GestureSet != None)
        LinkSkelAnim(GestureSet);
    if (GestureSet == None || !HasAnim(CastGesture))
    {
        LinkSkelAnim(Animation'HPModels.skHarryAnims');
        CastGesture = 'Cast';
    }
    ConfiguredMesh = CandidateMesh;
    Log("HPVersusCastGesture mesh=" $ string(CandidateMesh)
        $ " set=" $ string(SkelAnim)
        $ " sequence=" $ string(CastGesture)
        $ " available=" $ string(HasAnim(CastGesture)));
}

function PlayRemoteCast()
{
    if (HPVersusHarry(Owner) != None)
        ConfigureForMesh(HPVersusHarry(Owner).Mesh);

    if (IsInState('stateCast'))
        GotoState('stateIdle');
    GotoState('stateCast');
}

auto state stateIdle
{
}

// The observing viewport releases this layer against its replicated base
// sequence in HPVersusHarry.RestoreVersusRemoteBaseAnimation.
state stateRelease
{
}

state stateCast
{
begin:
    PlayAnim(CastGesture, 2.0, 0.1);
    FinishAnim();
    GotoState('stateRelease');
}
