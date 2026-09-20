// Authority-only bridge for original story callbacks that require a HPHud.
// Root integration assigns this to the server pawn's myHUD. Clients keep
// their own rendering HPHud; this actor never creates a CutSceneManager.
class HPCoopServerHUD extends HPHud;

simulated function PreBeginPlay()
{
    if (Role != ROLE_Authority || Level.NetMode == NM_Client)
    {
        Destroy();
        return;
    }
    // HPHud.PreBeginPlay would spawn local subtitle/border widgets.
    Super(HUD).PreBeginPlay();
}

simulated function PostBeginPlay()
{
    Super(HUD).PostBeginPlay();
    PlayerOwner = PlayerPawn(Owner);
}

function HPCoopGame GetStoryRelayGame()
{
    local HPCoopGame G;

    if (Role != ROLE_Authority || Level.NetMode == NM_Client)
        return None;
    G = HPCoopGame(Level.Game);
    if (G == None || harry(Owner) == None || harry(Owner) != G.StoryLeader)
        return None;
    return G;
}

function StartCutScene()
{
    local HPCoopGame G;

    G = GetStoryRelayGame();
    if (G == None)
        return;
    // Original ChallengeScoreManager.Timer reads this inherited flag.
    bCutSceneMode = True;
    bCutPopupMode = False;
    G.SetStoryCaptured(True);
}

function EndCutScene()
{
    local HPCoopGame G;

    G = GetStoryRelayGame();
    if (G == None)
        return;
    bCutSceneMode = False;
    bCutPopupMode = False;
    G.SetStoryCaptured(False);
}

function SetSubtitleText(string Text, float Duration)
{
    local HPCoopGame G;

    G = GetStoryRelayGame();
    if (G != None)
        G.BroadcastCoopSubtitle(Text, Duration);
}

function ClearSubtitleText()
{
    local HPCoopGame G;

    G = GetStoryRelayGame();
    if (G != None)
        G.BroadcastCoopSubtitle("", 0);
}

function bool IsCutSceneOrPopupInProgress()
{
    // HPHud's query also dereferences managerCutScene, which is absent here.
    return bCutSceneMode || bCutPopupMode;
}

// RegisterChallengeManager is inherited unchanged: original BeginChallenge
// stores its manager in the inherited managerChallenge field on this relay.
// HPHud.Tick only updates plain counters and is safe to retain.

simulated event PreRender(Canvas RenderCanvas)
{
}

simulated function PostRender(Canvas RenderCanvas)
{
}

simulated function HUDSetup(Canvas RenderCanvas)
{
}

simulated function bool DisplayMessages(Canvas RenderCanvas)
{
    return True;
}

exec function HideHud()
{
    // No server console/menu presentation is associated with this actor.
}

function ShowPopup(Class<basePopup> PopupClass)
{
    // Full campaign popups need a separate client presentation contract.
    Log("[MP_STORY] server HUD popup unsupported class=" $ PopupClass);
}

auto state ServerRelay
{
}

defaultproperties
{
    InitialState=ServerRelay
    RemoteRole=ROLE_None
    bGameRelevant=True
    bHidden=True
    DrawType=DT_None
    bDrawColPFXFirst=False
    bCollideActors=False
    bCollideWorld=False
}
