// Automated structural audit used only by the explicit mechanics probe.
class HPVersusCharacterAudit extends Info;

function bool HasRequiredAnimations(HPVersusHarry H)
{
    return H.HasAnim(H.HarryAnims[0].Idle)
        && H.HasAnim(H.HarryAnims[0].run)
        && H.HasAnim(H.HarryAnims[0].WalkBack)
        && H.HasAnim(H.HarryAnims[0].StrafeLeft)
        && H.HasAnim(H.HarryAnims[0].StrafeRight)
        && H.HasAnim(H.HarryAnims[0].Jump)
        && H.HasAnim(H.HarryAnims[0].Fall)
        && H.HasAnim(H.HarryAnims[0].Land)
        && H.HasAnim('Cast')
        && H.HasAnim('CastAim')
        && H.HasAnim('faint');
}

function RunAudit(HPVersusHarry H)
{
    local int I;
    local string ProfileId;
    local string ProfileStatus;
    local string SavedProfile;
    local bool bCorePass;
    local int CloakBone1;
    local int CloakBone2;
    local HPVersusPRI VPRI;

    if (Role != ROLE_Authority || H == None)
        return;

    VPRI = HPVersusPRI(H.PlayerReplicationInfo);
    if (VPRI != None)
        SavedProfile = VPRI.SelectedCharacter;
    else
        SavedProfile = "Harry";

    Log("HPVersusCharacterAudit START profiles="
        $ string(class'HPVersusCharacterProfiles'.static.GetProfileCount()));

    for (I = 0;
        I < class'HPVersusCharacterProfiles'.static.GetProfileCount();
        I++)
    {
        ProfileId = class'HPVersusCharacterProfiles'.static.GetProfileId(I);
        ProfileStatus = class'HPVersusCharacterProfiles'.static.GetAuditStatus(
            ProfileId);
        if (ProfileStatus ~= "BLOCKED")
        {
            Log("HPVersusCharacterAudit BLOCKED profile=" $ ProfileId
                $ " reason=configured-incompatible");
            continue;
        }
        H.ApplyCharacterSkin(ProfileId);
        CloakBone1 = H.BoneNumber(name("~Cloak01"));
        CloakBone2 = H.BoneNumber(name("~Cloak02"));
        bCorePass = H.Mesh != None
            && H.CollisionRadius == 15.0
            && H.CollisionHeight == 42.0
            && H.BoneNumber(
                class'HPVersusCharacterProfiles'.static.GetWandBone(ProfileId)) >= 0
            && HasRequiredAnimations(H);

        if (!bCorePass)
        {
            Log("HPVersusCharacterAudit BLOCKED profile=" $ ProfileId
                $ " mesh=" $ string(H.Mesh)
                $ " wandBone=" $ string(H.BoneNumber(
                    class'HPVersusCharacterProfiles'.static.GetWandBone(ProfileId)))
                $ " collision=" $ string(H.CollisionRadius)
                $ "x" $ string(H.CollisionHeight));
            Log("HPVersusCharacterAudit boneCandidates profile=" $ ProfileId
                $ " handSpaced=" $ string(H.BoneNumber('Bip01 R Hand'))
                $ " handCompact=" $ string(H.BoneNumber('Bip01 RHand'))
                $ " forearm=" $ string(H.BoneNumber('Bip01 R Forearm'))
                $ " finger=" $ string(H.BoneNumber('Bip01 R Finger0'))
                $ " rightHand=" $ string(H.BoneNumber('RightHand'))
                $ " handR=" $ string(H.BoneNumber('hand_r'))
                $ " spine=" $ string(H.BoneNumber('Bip01 Spine2')));
        }
        else if (ProfileStatus ~= "NEEDS EXTRA CHANNEL")
            Log("HPVersusCharacterAudit NEEDS_EXTRA_CHANNEL profile="
                $ ProfileId $ " cloakRoots=" $ string(CloakBone1)
                $ "," $ string(CloakBone2));
        else if (ProfileStatus ~= "NEEDS VISUAL FIX")
            Log("HPVersusCharacterAudit NEEDS_VISUAL_FIX profile="
                $ ProfileId $ " mesh=" $ string(H.Mesh)
                $ " wandBone=" $ string(H.BoneNumber(
                    class'HPVersusCharacterProfiles'.static.GetWandBone(ProfileId))));
        else
            Log("HPVersusCharacterAudit PASS profile=" $ ProfileId
                $ " mesh=" $ string(H.Mesh)
                $ " wandBone=" $ string(H.BoneNumber(
                    class'HPVersusCharacterProfiles'.static.GetWandBone(ProfileId)))
                $ " cloakRoots=" $ string(CloakBone1)
                $ "," $ string(CloakBone2));
    }

    if (VPRI != None)
        VPRI.SetSelectedCharacter(SavedProfile);
    H.ApplyCharacterSkin(SavedProfile);
    Log("HPVersusCharacterAudit COMPLETE restored=" $ SavedProfile);
}

defaultproperties
{
    RemoteRole=ROLE_None
    bHidden=True
}
