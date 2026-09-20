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

// Explicit travel probe handoff. Only the game's known spell classes are
// accepted; a map or package with an unknown spell cannot silently lose it.
static function Class<baseSpell> KnownSpellAt(int Slot)
{
    if (Slot == Class'spellFlipendo'.Default.SpellType) return Class'spellFlipendo';
    if (Slot == Class'spellLumos'.Default.SpellType) return Class'spellLumos';
    if (Slot == Class'spellAlohomora'.Default.SpellType) return Class'spellAlohomora';
    if (Slot == Class'spellSkurge'.Default.SpellType) return Class'spellSkurge';
    if (Slot == Class'spellRictusempra'.Default.SpellType) return Class'spellRictusempra';
    if (Slot == Class'spellDiffindo'.Default.SpellType) return Class'spellDiffindo';
    if (Slot == Class'spellSpongify'.Default.SpellType) return Class'spellSpongify';
    if (Slot == Class'spellDuelRictusempra'.Default.SpellType) return Class'spellDuelRictusempra';
    if (Slot == Class'spellDuelMimblewimble'.Default.SpellType) return Class'spellDuelMimblewimble';
    if (Slot == Class'spellDuelExpelliarmus'.Default.SpellType) return Class'spellDuelExpelliarmus';
    return None;
}

static function string EncodeTravelSpells(harry H)
{
    local int I;
    local string Mask;
    if (H == None || H.Role != ROLE_Authority) return "";
    if (H.SpellBook[Class'spellFlipendo'.Default.SpellType] != Class'spellFlipendo'
        || H.SpellBook[Class'spellLumos'.Default.SpellType] != Class'spellLumos'
        || H.SpellBook[Class'spellAlohomora'.Default.SpellType] != Class'spellAlohomora')
        return "";
    for (I = 0; I < 32; I++)
    {
        if (H.SpellBook[I] == None)
            Mask = Mask $ "0";
        else
        {
            if (H.SpellBook[I] != KnownSpellAt(I)) return "";
            Mask = Mask $ "1";
        }
    }
    return Mask;
}

// InitGame runs before native game-state screening. The GameState URL option
// sets only the string on the map Harry, so complete its coherent index and
// spellbook here, before CaptureFrom and before accepting destination logins.
static function bool SeedTravelState(harry H, string State, string Mask)
{
    local int I;
    local Class<baseSpell> S;
    if (H == None || H.bDeleteMe || H.Role != ROLE_Authority
        || H.Level == None || H.Level.TimeSeconds != 0)
        return False;
    if (Len(State) != 9 || !(Left(State, 6) ~= "GSTATE")
        || Len(Mask) != 32 || !(H.CurrentGameState ~= State))
        return False;
    for (I = 6; I < 9; I++)
        if (InStr("0123456789", Mid(State, I, 1)) < 0)
            return False;
    for (I = 0; I < 32; I++)
    {
        if (Mid(Mask, I, 1) != "0" && Mid(Mask, I, 1) != "1") return False;
        S = KnownSpellAt(I);
        if (Mid(Mask, I, 1) == "1" && S == None) return False;
    }
    if (Mid(Mask, Class'spellFlipendo'.Default.SpellType, 1) != "1"
        || Mid(Mask, Class'spellLumos'.Default.SpellType, 1) != "1"
        || Mid(Mask, Class'spellAlohomora'.Default.SpellType, 1) != "1")
        return False;
    for (I = 0; I < 32; I++)
        if (Mid(Mask, I, 1) == "1") H.SpellBook[I] = KnownSpellAt(I);
        else H.SpellBook[I] = None;
    H.iGameState = int(Right(State, 3));
    H.bNoSpellBookCheck = False;
    Log("[MP_STORY_STATE] origin=travel-probe phase=InitGame state=" $ State
        $ " index=" $ H.iGameState $ " mask=" $ Mask $ " pawn=" $ H);
    return True;
}

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
    Log("[MP_STORY_STATE] captured map=" $ Level.Outer.Name
        $ " state=" $ StoryState $ " index=" $ StoryIndex
        $ " spells=" $ LearnedSpellCount $ " fixture=" $ FixtureName
        $ " ready=" $ IsSnapshotReady()
        $ " rictusempra=" $ LearnedSpells[Class'spellRictusempra'.Default.SpellType]);
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
