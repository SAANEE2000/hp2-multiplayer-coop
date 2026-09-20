// Opt-in for the Ch1 intro. All parsing, captures, speech and cues are inherited.
// Completing a thread must not release a scene transferred to another thread.
class HPCoopCutScriptDisk extends CutScriptDisk;

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

function CutCue(string Cue)
{
    local HPCoopGame G;
    Super.CutCue(Cue);
    G = HPCoopGame(Level.Game);
    if (G != None && G.bCoopCapturedAuthorityDiagnostic && G.StoryLeader != None)
        G.StoryLeader.CoopOriginalWalkCueReceived(self, Cue);
}
