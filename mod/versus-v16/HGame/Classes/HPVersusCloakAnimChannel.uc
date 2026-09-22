//=============================================================================
// HPVersusCloakAnimChannel.
//
// Ron and Hermione's playable meshes use a character-specific cloak skeleton.
// Their body is driven by skHarryAnims for the complete player move set, while
// this channel supplies the matching generic-student animation only below a
// cloak root bone. It never changes movement, collision or the body pose.
//=============================================================================

class HPVersusCloakAnimChannel extends AnimChannel;

simulated function Configure(bool bFemale)
{
    if (bFemale)
        LinkSkelAnim(Animation'HPModels.skGenFemaleAnims');
    else
        LinkSkelAnim(Animation'HPModels.skGenMaleAnims');

    bAnimNotReplaceable = True;
}

simulated function bool PlayCloakAnimation(name SequenceName, bool bLooping)
{
    if (!HasAnim(SequenceName))
        return False;

    if (bLooping)
        LoopAnim(SequenceName, 1.0, 0.15);
    else
        PlayAnim(SequenceName, 1.0, 0.15);

    return True;
}

defaultproperties
{
    DrawType=DT_None
    bHidden=True
}
