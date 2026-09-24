// Replicated examples of the real stock meshes available to the disguise list.
class HPHideSeekArenaProp extends Actor;

var byte DisguiseProfile;

replication
{
    reliable if (Role == ROLE_Authority)
        DisguiseProfile;
}

function Configure(byte NewProfile)
{
    if (Role != ROLE_Authority
        || !class'HPHideSeekDisguiseCatalog'.static.IsValid(NewProfile)
        || NewProfile == 0)
        return;
    DisguiseProfile = NewProfile;
    ApplyProfile();
}

simulated event PostNetReceive()
{
    ApplyProfile();
}

simulated function ApplyProfile()
{
    local Mesh ProfileMesh;

    ProfileMesh = class'HPHideSeekDisguiseCatalog'.static.GetMesh(
        DisguiseProfile);
    if (ProfileMesh == None)
        return;
    Mesh = ProfileMesh;
    DrawScale = class'HPHideSeekDisguiseCatalog'.static.GetDrawScale(
        DisguiseProfile);
}

defaultproperties
{
    DrawType=DT_Mesh
    bStatic=False
    bNoDelete=False
    bCollideActors=False
    bCollideWorld=False
    bBlockActors=False
    bBlockPlayers=False
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=True
}
