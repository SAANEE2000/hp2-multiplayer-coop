// Fixed server-approved disguise profiles. Collision always remains the
// HPVersusHarry capsule; these values are presentation only.
class HPHideSeekDisguiseCatalog extends Object;

const DISGUISE_COUNT = 6;

static function bool IsValid(byte ProfileIndex)
{
    return ProfileIndex <= DISGUISE_COUNT;
}

static function Mesh GetMesh(byte ProfileIndex)
{
    switch (ProfileIndex)
    {
        case 1: return SkeletalMesh'HProps.skBarrelMinersMesh';
        case 2: return SkeletalMesh'HPModels.skwoodchestMesh';
        case 3: return SkeletalMesh'HPModels.skbronzecauldronMesh';
        case 4: return SkeletalMesh'HProps.skVaseUrnMesh';
        case 5: return SkeletalMesh'HProps.skChairsWood1Mesh';
        case 6: return SkeletalMesh'HProps.skBoxSmallWoodenMesh';
    }
    return None;
}

static function float GetDrawScale(byte ProfileIndex)
{
    if (ProfileIndex == 1)
        return 0.40;
    if (ProfileIndex == 6)
        return 1.20;
    return 1.00;
}

static function string GetDisplayName(byte ProfileIndex)
{
    switch (ProfileIndex)
    {
        case 1: return "BARREL";
        case 2: return "WOODEN CHEST";
        case 3: return "BRONZE CAULDRON";
        case 4: return "VASE";
        case 5: return "WOODEN CHAIR";
        case 6: return "WOODEN BOX";
    }
    return "NONE";
}
