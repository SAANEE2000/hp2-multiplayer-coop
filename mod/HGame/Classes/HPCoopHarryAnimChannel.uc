// Original animation labels with server-owned potion completion.
class HPCoopHarryAnimChannel extends cHarryAnimChannel;

function DoKnockBack()
{
    Super.DoKnockBack();
    if (HPCoopHarry(Owner) != None) HPCoopHarry(Owner).CoopNotifyKnockBack();
}

state stateDrinkWiggenwell
{
    function EndState()
    {
        if (propTemp != None)
        {
            propTemp.bHidden = True;
            harry(Owner).DropCarryingActor();
            propTemp.Destroy();
            propTemp = None;
        }
        bAnimNotReplaceable = False;
        // Authority owns completion, including original animation interruption.
        // Do not call the inherited EndState: it mutates the local status model.
        if (HPCoopHarry(Owner) != None)
            HPCoopHarry(Owner).CompleteCoopPotion();
    }
}
