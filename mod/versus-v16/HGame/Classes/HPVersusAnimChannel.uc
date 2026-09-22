//=============================================================================
// HPVersusAnimChannel.
//
// Ron and Hermione use HP2's generic student animation sets. Those sets have
// duel_charge/cast but do not have Harry's CastAim sequence. Keep Harry's
// stock channel behavior while selecting the supported aiming loop for the
// two cosmetic multiplayer meshes.
//=============================================================================

class HPVersusAnimChannel extends cHarryAnimChannel;

state stateCasting
{
begin:
    harry(Owner).HarryAnimType = AT_Combine;
    if (harry(Owner).bHarryUsingSword)
    {
        LoopAnim('swordaim', 1.0, 0.2);
    }
    else if (HPVersusHarry(Owner) != None
        && HPVersusHarry(Owner).UsesVersusGenericAnimationSet())
    {
        LoopAnim('duel_charge', 1.0, 0.2);
    }
    else if (harry(Owner).bInDuelingMode)
    {
        LoopAnim('duel_charge', 1.0, 0.2);
    }
    else
    {
        LoopAnim('CastAim', 1.0, 0.2);
    }
}
