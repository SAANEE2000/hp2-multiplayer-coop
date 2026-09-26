//=============================================================================
// HPVersusCharacterProfiles.
//
// Central cosmetic profile table. Every entry is still played by
// HPVersusHarry and therefore keeps the same health, movement and collision.
//=============================================================================

class HPVersusCharacterProfiles extends Object;

const PROFILE_COUNT = 27;
const ANIM_NATIVE_HARRY = 0;
const ANIM_LINK_HARRY = 1;
const CLOAK_NONE = 0;
const CLOAK_GENERIC_MALE = 1;
const CLOAK_GENERIC_FEMALE = 2;

struct VersusCharacterProfile
{
    var() string Id;
    var() string DisplayName;
    var() string GroupName;
    var() Mesh BodyMesh;
    var() float DrawScale;
    var() byte AnimationStrategy;
    var() byte CloakStrategy;
    var() name WandBone;
    var() float VisualOffsetZ;
    var() bool bTranslucent;
    var() float Opacity;
    var() Texture Skin0;
    var() Texture Skin1;
    var() bool bSelectable;
    var() string AuditStatus;
};

var VersusCharacterProfile Profiles[27];

static function int FindProfile(string ProfileId)
{
    local int I;

    for (I = 0; I < PROFILE_COUNT; I++)
        if (Default.Profiles[I].Id ~= ProfileId)
            return I;

    return -1;
}

static function int GetProfileCount()
{
    return PROFILE_COUNT;
}

static function string GetProfileId(int ProfileIndex)
{
    if (ProfileIndex < 0 || ProfileIndex >= PROFILE_COUNT)
        return "";
    return Default.Profiles[ProfileIndex].Id;
}

static function int FindProfileByMesh(Mesh CandidateMesh)
{
    local int I;

    for (I = 0; I < PROFILE_COUNT; I++)
        if (Default.Profiles[I].BodyMesh == CandidateMesh)
            return I;

    return -1;
}

static function string ValidateProfileId(string ProfileId)
{
    local int I;

    I = FindProfile(ProfileId);
    if (I >= 0 && Default.Profiles[I].bSelectable)
        return Default.Profiles[I].Id;

    return "Harry";
}

static function bool IsSelectable(string ProfileId)
{
    local int I;

    I = FindProfile(ProfileId);
    return I >= 0 && Default.Profiles[I].bSelectable;
}

static function Mesh GetMesh(string ProfileId)
{
    local int I;

    I = FindProfile(ValidateProfileId(ProfileId));
    return Default.Profiles[I].BodyMesh;
}

static function float GetDrawScale(string ProfileId)
{
    local int I;

    I = FindProfile(ValidateProfileId(ProfileId));
    return Default.Profiles[I].DrawScale;
}

static function float GetVisualOffsetZ(string ProfileId)
{
    local int I;

    I = FindProfile(ValidateProfileId(ProfileId));
    return Default.Profiles[I].VisualOffsetZ;
}

static function Texture GetSkin(string ProfileId, byte SkinIndex)
{
    local int I;

    I = FindProfile(ValidateProfileId(ProfileId));
    if (SkinIndex == 0)
        return Default.Profiles[I].Skin0;
    if (SkinIndex == 1)
        return Default.Profiles[I].Skin1;
    return None;
}

static function bool IsTranslucent(string ProfileId)
{
    local int I;

    I = FindProfile(ValidateProfileId(ProfileId));
    return Default.Profiles[I].bTranslucent;
}

static function float GetOpacity(string ProfileId)
{
    local int I;

    I = FindProfile(ValidateProfileId(ProfileId));
    return Default.Profiles[I].Opacity;
}

static function bool ShouldLinkHarryAnimations(Mesh CandidateMesh)
{
    local int I;

    I = FindProfileByMesh(CandidateMesh);
    return I >= 0
        && Default.Profiles[I].AnimationStrategy == ANIM_LINK_HARRY;
}

static function byte GetCloakStrategy(Mesh CandidateMesh)
{
    local int I;

    I = FindProfileByMesh(CandidateMesh);
    if (I < 0)
        return CLOAK_NONE;
    return Default.Profiles[I].CloakStrategy;
}

static function name GetWandBone(string ProfileId)
{
    local int I;

    I = FindProfile(ValidateProfileId(ProfileId));
    return Default.Profiles[I].WandBone;
}

static function string GetAuditStatus(string ProfileId)
{
    local int I;

    I = FindProfile(ProfileId);
    if (I < 0)
        return "BLOCKED";
    return Default.Profiles[I].AuditStatus;
}

defaultproperties
{
    Profiles(0)=(Id="Harry",DisplayName="Harry",GroupName="Gryffindor",BodyMesh=SkeletalMesh'HPModels.skharryMesh',DrawScale=1.0,AnimationStrategy=0,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="PASS")
    Profiles(1)=(Id="Ron",DisplayName="Ron",GroupName="Gryffindor",BodyMesh=SkeletalMesh'HPModels.skronPlayerMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=1,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="PASS")
    Profiles(2)=(Id="Hermione",DisplayName="Hermione",GroupName="Gryffindor",BodyMesh=SkeletalMesh'HPModels.skhermionePlayerMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=2,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="PASS")
    Profiles(3)=(Id="Ginny",DisplayName="Ginny",GroupName="Gryffindor",BodyMesh=SkeletalMesh'HPModels.skGinnyMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=2,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="PASS")
    Profiles(4)=(Id="Fred",DisplayName="Fred",GroupName="Gryffindor",BodyMesh=SkeletalMesh'HPModels.skFredWeasleyMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS EXTRA CHANNEL")
    Profiles(5)=(Id="George",DisplayName="George",GroupName="Gryffindor",BodyMesh=SkeletalMesh'HPModels.skGeorgeWeasleyMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS EXTRA CHANNEL")
    Profiles(6)=(Id="Percy",DisplayName="Percy",GroupName="Gryffindor",BodyMesh=SkeletalMesh'HPModels.skPercyMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS EXTRA CHANNEL")
    Profiles(7)=(Id="OliverWood",DisplayName="Oliver Wood",GroupName="Gryffindor",BodyMesh=SkeletalMesh'HPModels.skOliverWoodMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS EXTRA CHANNEL")
    Profiles(8)=(Id="GryffindorStudentM",DisplayName="Gryffindor Student M",GroupName="Gryffindor",BodyMesh=SkeletalMesh'HPModels.skhp2_genmale1Mesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=1,WandBone="Bip01 R Hand",Opacity=1.0,Skin0=Texture'HPModels.Skins.skhp2_genmale1_0Tex0',Skin1=Texture'HPModels.Skins.skhp2_genmale1_0Tex1',bSelectable=True,AuditStatus="PASS")
    Profiles(9)=(Id="GryffindorStudentF",DisplayName="Gryffindor Student F",GroupName="Gryffindor",BodyMesh=SkeletalMesh'HPModels.skhp2_genfemale1Mesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=2,WandBone="Bip01 R Hand",Opacity=1.0,Skin0=Texture'HPModels.Skins.skhp2_genfemale1_1Tex0',Skin1=Texture'HPModels.Skins.skhp2_genfemale1_1Tex1',bSelectable=True,AuditStatus="PASS")
    Profiles(10)=(Id="Draco",DisplayName="Draco",GroupName="Slytherin",BodyMesh=SkeletalMesh'HPModels.skDracoMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=1,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="PASS")
    Profiles(11)=(Id="Crabbe",DisplayName="Crabbe",GroupName="Slytherin",BodyMesh=SkeletalMesh'HPModels.skCrabbeMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=1,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="PASS")
    Profiles(12)=(Id="Goyle",DisplayName="Goyle",GroupName="Slytherin",BodyMesh=SkeletalMesh'HPModels.skGoyleMesh',DrawScale=1.15,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS EXTRA CHANNEL")
    Profiles(13)=(Id="SlytherinPrefect",DisplayName="Slytherin Prefect",GroupName="Slytherin",BodyMesh=SkeletalMesh'HPModels.skSlytherinPrefectMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS EXTRA CHANNEL")
    Profiles(14)=(Id="TomRiddle",DisplayName="Tom Riddle",GroupName="Slytherin",BodyMesh=SkeletalMesh'HPModels.skTomRiddleMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS EXTRA CHANNEL")
    Profiles(15)=(Id="SlytherinStudentM",DisplayName="Slytherin Student M",GroupName="Slytherin",BodyMesh=SkeletalMesh'HPModels.skhp2_genmale2Mesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=1,WandBone="Bip01 R Hand",Opacity=1.0,Skin0=Texture'HPModels.Skins.skhp2_genmale1_7Tex0',Skin1=Texture'HPModels.Skins.skhp2_genmale1_7Tex1',bSelectable=True,AuditStatus="PASS")
    Profiles(16)=(Id="SlytherinStudentF",DisplayName="Slytherin Student F",GroupName="Slytherin",BodyMesh=SkeletalMesh'HPModels.skhp2_genfemale2Mesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=2,WandBone="Bip01 R Hand",Opacity=1.0,Skin0=Texture'HPModels.Skins.skhp2_genfemale1_7Tex0',Skin1=Texture'HPModels.Skins.skhp2_genfemale1_7Tex1',bSelectable=True,AuditStatus="PASS")
    Profiles(17)=(Id="Snape",DisplayName="Snape",GroupName="Adults",BodyMesh=SkeletalMesh'HPModels.skProfSnapeMesh',DrawScale=1.18,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS EXTRA CHANNEL")
    Profiles(18)=(Id="Lockhart",DisplayName="Lockhart",GroupName="Adults",BodyMesh=SkeletalMesh'HPModels.skProfLockhartMesh',DrawScale=1.15,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS EXTRA CHANNEL")
    Profiles(19)=(Id="Dumbledore",DisplayName="Dumbledore",GroupName="Adults",BodyMesh=SkeletalMesh'HPModels.skProfDumbledoreMesh',DrawScale=1.20,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS EXTRA CHANNEL")
    Profiles(20)=(Id="McGonagall",DisplayName="McGonagall",GroupName="Adults",BodyMesh=SkeletalMesh'HPModels.skProfMcGonagallMesh',DrawScale=1.18,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS EXTRA CHANNEL")
    Profiles(21)=(Id="Hagrid",DisplayName="Hagrid",GroupName="Adults",BodyMesh=SkeletalMesh'HPModels.skHagridMesh',DrawScale=1.25,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS VISUAL FIX")
    Profiles(22)=(Id="Lucius",DisplayName="Lucius Malfoy",GroupName="Adults",BodyMesh=SkeletalMesh'HPModels.skLuciousMalfoyMesh',DrawScale=1.16,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS EXTRA CHANNEL")
    Profiles(23)=(Id="Dobby",DisplayName="Dobby",GroupName="Fun",BodyMesh=SkeletalMesh'HPModels.skdobbyMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",Opacity=1.0,bSelectable=True,AuditStatus="NEEDS VISUAL FIX")
    Profiles(24)=(Id="MoaningMyrtle",DisplayName="Moaning Myrtle",GroupName="Fun",BodyMesh=SkeletalMesh'HPModels.skmoaningmyrtleMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",bTranslucent=True,Opacity=0.75,bSelectable=True,AuditStatus="NEEDS VISUAL FIX")
    Profiles(25)=(Id="NearlyHeadlessNick",DisplayName="Nearly Headless Nick",GroupName="Fun",BodyMesh=SkeletalMesh'HPModels.skNHNickMesh',DrawScale=1.0,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",bTranslucent=True,Opacity=0.75,bSelectable=True,AuditStatus="NEEDS VISUAL FIX")
    Profiles(26)=(Id="BloodyBaron",DisplayName="Bloody Baron",GroupName="Fun",BodyMesh=SkeletalMesh'HPModels.skbloodybaronMesh',DrawScale=1.20,AnimationStrategy=1,CloakStrategy=0,WandBone="Bip01 R Hand",bTranslucent=True,Opacity=0.75,bSelectable=False,AuditStatus="BLOCKED")
}
