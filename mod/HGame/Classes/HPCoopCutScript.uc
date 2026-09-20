// Preserve the original inline-script interpreter while logging safely on a server.
class HPCoopCutScript extends CutScript;

function string CoopLogContext()
{
    local string Context;
    Context = sThreadName;
    if (Context == "")
        Context = string(self);
    if (ScriptLayers.Length > 0)
        Context = Context @ ScriptLayers[ScriptLayers.Length - 1].LayerName;
    return Context;
}

function CutLog(string Str)
{
    if (Role != ROLE_Authority || !bLogCutscene)
        return;
    Log("[MP_CUT] " $ CoopLogContext() $ " -> " $ Str);
}

function CutError(string Str)
{
    if (Role != ROLE_Authority)
        return;
    Log("[MP_CUT_ERROR] " $ CoopLogContext() $ " -> " $ Str);
}
