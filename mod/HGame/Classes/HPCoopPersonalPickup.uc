// Authority pickup adapter for original personal Ch1 health/potion props.
// Depends on the narrow HProp recipe and each collector's own status chain.
class HPCoopPersonalPickup extends Info abstract;

static function bool Handles(HProp P)
{
    return P != None && (P.IsA('ChocolateFrog') || P.IsA('WiggenWell'));
}

static function bool TryCollect(HProp P, Actor Other)
{
    local HPCoopGame G;
    local HPCoopHarry H;
    local StatusGroup Group;
    local StatusItem Item;
    local int I, BeforeCount;
    local bool bRegisteredReady;
    local Sound PickupSound;

    if (!Handles(P) || P.bDeleteMe || P.Role != ROLE_Authority
        || P.Level.NetMode == NM_Client || P.bCoopPickupClaimed)
        return False;
    if (!(string(P.Level.Outer.Name) ~= "Ch1Rictusempra")) return False;
    G = HPCoopGame(P.Level.Game);
    H = HPCoopHarry(Other);
    if (G == None || H == None || H.Level != P.Level || H.Role != ROLE_Authority
        || !G.IsAliveCoopPlayer(H) || G.bWaitingForPlayers || G.bStoryCaptured
        || G.bCoopRecoveryBlocked || H.bCoopStoryCaptured || H.bCoopAwaitResume
        || H.bCoopSceneMode || H.bCoopSceneAwaitRelease)
        return False;
    for (I = 0; I < 2; I++)
        if (G.CoopPlayers[I] == H && G.ReadyPlayers[I] != 0)
            bRegisteredReady = True;
    if (!bRegisteredReady || H.IsEngagedWithVendor() || H.IsMixingPotion())
        return False;
    if (!P.bPickupOnTouch || !P.bCollideActors || P.bHidden
        || P.IsInState('PickupProp') || P.IsInState('DropOffProp')
        || Pawn(P.Owner) != None || P.AttachmentBone != '')
        return False;
    // These are animation/mixing props, not the world drops in this milestone.
    if (P.Class != Class'ChocolateFrog' && P.Class != Class'WiggenWell'
        && P.Class != Class'WWellBlueBottle' && P.Class != Class'WWellOrangeBottle')
        return False;
    if (P.nPickupIncrement <= 0 || H.managerStatus == None
        || H.managerStatus.PlayerHarry != H)
        return False;
    if (P.Class == Class'ChocolateFrog')
    {
        if (P.classStatusGroup != Class'StatusGroupHealth'
            || P.classStatusItem != Class'StatusItemHealth') return False;
    }
    else if (P.classStatusGroup != Class'StatusGroupPotions'
        || P.classStatusItem != Class'StatusItemWiggenwell') return False;

    Group = H.managerStatus.GetStatusGroup(P.classStatusGroup);
    if (Group == None || Group.smParent != H.managerStatus) return False;
    Item = Group.GetStatusItem(P.classStatusItem);
    if (Item == None || Item.sgParent != Group) return False;
    BeforeCount = Item.nCount;

    // Synchronous claim precedes callbacks: two touches can grant only once.
    // Never assign the prop's cached PlayerHarry or the global story alias.
    P.bCoopPickupClaimed = True;
    P.bPickupOnTouch = False;
    P.SetCollision(False, False, False);
    P.GotoState('');
    P.SetTimer(0.0, False);
    P.Disable('Tick');
    H.managerStatus_PickupItem(P);
    H.PublishCoopStatus();

    PickupSound = P.soundPickup;
    if (P.soundPickup != None && P.soundPickup2 != None && Rand(2) != 0)
        PickupSound = P.soundPickup2;
    else if (PickupSound == None)
        PickupSound = P.soundPickup2;
    if (PickupSound != None) P.PlaySound(PickupSound);
    P.Log("[MP_PICKUP] collector=" $ H $ " prop=" $ P $ " item=" $ Item.Class
        $ " before=" $ BeforeCount $ " after=" $ Item.nCount
        $ " requested=" $ P.nPickupIncrement);
    // Preserve the original event's Other/Instigator arguments and order.
    if (P.EventToSendOnPickup != 'None')
        P.TriggerEvent(P.EventToSendOnPickup, P, P);
    P.bHidden = True;
    P.Destroy();
    return True;
}
