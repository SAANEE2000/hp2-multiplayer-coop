// Disposable native-travel diagnostic after the complete original Ch1 intro.
class HPCoopTravelProbe extends Info;

var HPCoopGame Game;
var bool bIssued;
var float Deadline;
var string TravelSpells;

event PostBeginPlay()
{
    Super.PostBeginPlay();
    Game = HPCoopGame(Level.Game);
    if (Role != ROLE_Authority || Level.NetMode != NM_DedicatedServer
        || Game == None || !(Game.RuntimeProbe ~= "Travel")
        || !Game.bCoopFirstIntroPreflight)
    {
        Destroy();
        return;
    }
    Deadline = Level.TimeSeconds + 180;
    SetTimer(0.5, True);
    Log("[MP_TRAVEL] probe-armed destination=Entryhall_hub fixture=True");
}

event Timer()
{
    if (bIssued) return;
    if (Game == None || Game.IntroCoordinator == None
        || Game.IntroCoordinator.Phase == 6)
    {
        Log("[MP_TRAVEL] result=BLOCKED reason=intro-unavailable");
        Destroy();
        return;
    }
    if (Level.TimeSeconds >= Deadline)
    {
        Log("[MP_TRAVEL] result=BLOCKED reason=intro-timeout");
        Destroy();
        return;
    }
    if (Game.IntroCoordinator.Phase != 5 || Game.CoopPlayers[0] == None
        || Game.CoopPlayers[1] == None || Game.StoryLeader == None)
        return;
    if (!(Game.StoryLeader.CurrentGameState ~= "GSTATE030")
        || Game.StoryLeader.iGameState != 30)
    {
        Log("[MP_TRAVEL] result=BLOCKED reason=unexpected-story-state state="
            $ Game.StoryLeader.CurrentGameState);
        Destroy();
        return;
    }
    TravelSpells = Class'HPCoopCampaignState'.static.EncodeTravelSpells(Game.StoryLeader);
    if (TravelSpells == "")
    {
        Log("[MP_TRAVEL] result=BLOCKED reason=unsupported-spellbook");
        Destroy();
        return;
    }
    bIssued = True;
    Log("[MP_TRAVEL] issuing-native-servertravel leader=" $ Game.StoryLeader
        $ " slot0=" $ Game.CoopPlayers[0] $ " slot1=" $ Game.CoopPlayers[1]
        $ " state=" $ Game.StoryLeader.CurrentGameState
        $ " spells=" $ TravelSpells);
    // Relative travel inherits source URL options. Clear all Ch1-only test
    // flags explicitly before the destination GameInfo.InitGame runs.
    Level.ServerTravel("Entryhall_hub.unr?game=HGame.HPCoopGame?MaxPlayers=2"
        $ "?CoopTestStage=?CoopProbe=?CoopCapturedAuthority=0"
        $ "?CoopFirstIntroPreflight=0?GameState="
        $ Game.StoryLeader.CurrentGameState
        $ "?CoopTravelSource=Ch1Rictusempra?CoopTravelSpells="
        $ TravelSpells, True);
    Log("[MP_TRAVEL] requested next-url=" $ Level.NextURL);
}
