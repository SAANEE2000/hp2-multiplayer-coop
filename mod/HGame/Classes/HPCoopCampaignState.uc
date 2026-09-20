// Explicit launch fixture / initial shared snapshot. This is not a save format.
// Game owns when to seed/capture; clients may apply only to their local Harry.
class HPCoopCampaignState extends Actor;

const Ch1FixtureToken = "RictusempraLessonComplete";
const Ch1StoryState = "GSTATE030";

var Class<baseSpell> LearnedSpells[32];
var string StoryState;
var int StoryIndex;
var int LearnedSpellCount;
var bool bInitialized;
var bool bIsTestStage;
var string FixtureName;

replication
{
    reliable if (Role == ROLE_Authority)
        LearnedSpells, StoryState, StoryIndex, LearnedSpellCount, bInitialized, bIsTestStage, FixtureName;
}

// Invoke only from the explicitly opted-in Game.InitGame fresh-map path.
// Native screening happens after actor PostBeginPlay in the audited M212 DLL.
// Keep the seeded legacy pawn bIsPlayer until that native pass has completed.
static function bool SeedCh1TestStage(harry H)
{
    local int I;
    local Class<baseSpell> S;

    if (H == None || H.bDeleteMe || H.Level == None || H.Role != ROLE_Authority)
        return False;
    if (H.Level.NetMode == NM_Client || H.Level.TimeSeconds != 0
        || !(string(H.Level.Outer.Name) ~= "Ch1Rictusempra"))
        return False;
    // A travel/save state must never be overwritten by a launch fixture.
    if (H.CurrentGameState != "" && !(H.CurrentGameState ~= "None"))
        return False;
    for (I = 0; I < 32; I++)
    {
        S = H.SpellBook[I];
        if (S != None && S != Class'spellFlipendo' && S != Class'spellLumos'
            && S != Class'spellAlohomora')
            return False;
    }
    // Both values are fixed and validated; avoid early console/status callbacks.
    H.CurrentGameState = Ch1StoryState;
    H.iGameState = 30;
    H.AddToSpellBook(Class'spellFlipendo');
    H.AddToSpellBook(Class'spellLumos');
    H.AddToSpellBook(Class'spellAlohomora');
    H.AddToSpellBook(Class'spellRictusempra');
    H.bNoSpellBookCheck = False;
    Log("[MP_STORY_STATE] origin=test-stage fixture=" $ Ch1FixtureToken
        $ " phase=InitGame state=" $ H.CurrentGameState $ " pawn=" $ H);
    return True;
}

function bool CaptureFrom(harry H, optional string AppliedFixture)
{
    local int I;

    if (Role != ROLE_Authority || H == None || H.bDeleteMe || H.Level != Level)
        return False;
    if (AppliedFixture != "" && !(AppliedFixture ~= Ch1FixtureToken))
        return False;
    // Capture after the map actors' PreBeginPlay has populated base spells.
    if (H.SpellBook[Class'spellFlipendo'.Default.SpellType] != Class'spellFlipendo'
        || H.SpellBook[Class'spellLumos'.Default.SpellType] != Class'spellLumos'
        || H.SpellBook[Class'spellAlohomora'.Default.SpellType] != Class'spellAlohomora')
        return False;
    if (AppliedFixture != "" && (!(H.CurrentGameState ~= Ch1StoryState)
        || H.iGameState != 30
        || H.SpellBook[Class'spellRictusempra'.Default.SpellType] != Class'spellRictusempra'))
        return False;
    if (AppliedFixture != "")
        for (I = 0; I < 32; I++)
            if (H.SpellBook[I] != None && H.SpellBook[I] != Class'spellFlipendo'
                && H.SpellBook[I] != Class'spellLumos' && H.SpellBook[I] != Class'spellAlohomora'
                && H.SpellBook[I] != Class'spellRictusempra')
                return False;

    bInitialized = False;
    LearnedSpellCount = 0;
    for (I = 0; I < 32; I++)
    {
        LearnedSpells[I] = H.SpellBook[I];
        if (LearnedSpells[I] != None) LearnedSpellCount++;
    }
    StoryState = H.CurrentGameState;
    StoryIndex = H.iGameState;
    FixtureName = AppliedFixture;
    bIsTestStage = AppliedFixture != "";
    bInitialized = True;
    return True;
}

simulated function bool IsSnapshotReady()
{
    local int I, Count;

    if (!bInitialized || StoryState == "") return False;
    if (LearnedSpellCount < 3 || LearnedSpellCount > 32) return False;
    for (I = 0; I < 32; I++)
        if (LearnedSpells[I] != None)
        {
            if (LearnedSpells[I].Default.SpellType != I) return False;
            Count++;
        }
    if (Count != LearnedSpellCount) return False;
    if (StoryState ~= "None")
    {
        if (StoryIndex != 0) return False;
    }
    else if (Len(StoryState) != 9 || !(Left(StoryState, 6) ~= "GSTATE")
        || StoryIndex != int(Right(StoryState, 3)))
        return False;
    if (LearnedSpells[Class'spellFlipendo'.Default.SpellType] != Class'spellFlipendo'
        || LearnedSpells[Class'spellLumos'.Default.SpellType] != Class'spellLumos'
        || LearnedSpells[Class'spellAlohomora'.Default.SpellType] != Class'spellAlohomora')
        return False;
    // Replicated properties are not treated as an atomic batch.
    if (bIsTestStage && (!(FixtureName ~= Ch1FixtureToken)
        || !(StoryState ~= Ch1StoryState) || StoryIndex != 30
        || LearnedSpellCount != 4
        || LearnedSpells[Class'spellRictusempra'.Default.SpellType] != Class'spellRictusempra'))
        return False;
    return True;
}

// Apply once for an accepted initial snapshot, not every Tick forever.
// A future travel/save implementation needs revisions and authoritative updates.
simulated function bool ApplyTo(harry H)
{
    local int I;

    if (!IsSnapshotReady() || H == None || H.bDeleteMe || H.Level != Level)
        return False;
    if (Level.NetMode == NM_Client && (H.Player == None || Viewport(H.Player) == None))
        return False;
    for (I = 0; I < 32; I++)
        H.SpellBook[I] = LearnedSpells[I];
    H.CurrentGameState = StoryState;
    H.iGameState = StoryIndex;
    H.bNoSpellBookCheck = False;
    return True;
}

defaultproperties
{
    bHidden=True
    bAlwaysRelevant=True
    RemoteRole=ROLE_SimulatedProxy
}
