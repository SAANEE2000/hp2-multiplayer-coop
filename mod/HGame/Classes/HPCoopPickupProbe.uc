// Explicit synthetic authoritative contact fixture, not gameplay acceptance.
// Uses exact original prop classes and native MoveSmooth/Touch dispatch.
// Spawn/Arm only for an explicit disposable dedicated Ch1 pickup test.
class HPCoopPickupProbe extends Info;

var bool bOptIn, bArmed, bFinished, bPairReadySeen, bSawIntro, bSeeded;
var HPCoopGame Game;
var HPCoopHarry Players[2];
var StatusItem Potions[2];
var vector PlayerPositions[2];
var int ExpectedHealth[2], ExpectedPotions[2];
var HProp ActivePickup;
var harry OriginalPickupContext;
var int Phase, StepEvents, TotalEvents;
var bool bEventContractOK;
var float Deadline, NextStep;
var SavePoint ActiveSavePoint;
var harry SavePointContext;
var bool bHaveSavePointSnapshot, SavedBookActive, SavedBookSaveOnce, SavedBookHidden;
var bool SavedBookCollideActors, SavedBookBlockActors, SavedBookBlockPlayers, SavedBookCollideWorld;
var float SavedBookWait, SavedBookOpacity, SavedBookDilation;
var string SavedBookPauser;
var int SavedBookEventCount;

function string ProbeOption() { return "Pickup"; }

// Explicit option, spawn, bOptIn=True, Arm(G); ordinary play never arms it.
function bool Arm(HPCoopGame G)
{
    local Actor A;
    if (!bOptIn || bArmed || bFinished || Role != ROLE_Authority
        || Level.NetMode != NM_DedicatedServer || G == None || G != Level.Game
        || !(G.RuntimeProbe ~= ProbeOption())
        || !(G.TestStage ~= "RictusempraLessonComplete")
        || !(string(Level.Outer.Name) ~= "Ch1Rictusempra"))
    {
        Log("[MP_PROBE] probe=pickup arm-refused=context role=" $ Role
            $ " netmode=" $ Level.NetMode $ " map=" $ Level.Outer.Name
            $ " opt-in=" $ bOptIn $ " armed=" $ bArmed $ " game=" $ G);
        return False;
    }
    // Spawn must pass the explicit tag; this engine leaves omitted tags None.
    if (Tag != 'HPCoopPickupFixtureEvent') return False;
    // The original pickup event has a single fixture observer and no map target.
    foreach AllActors(Class'Actor', A, Tag)
        if (A != self)
        {
            Log("[MP_PROBE] probe=pickup arm-refused=tag-conflict tag=" $ Tag $ " actor=" $ A);
            return False;
        }
    Game = G;
    bArmed = True;
    Deadline = Level.TimeSeconds + 180;
    SetTimer(0.2, True);
    Log("[MP_PROBE] probe=pickup status=ARMED mode=synthetic-contact-fixture placed-map-pickups=False input=False visual=False two-pc=False");
    return True;
}

function Finish(string Result, string Reason)
{
    if (bFinished) return;
    bFinished = True;
    SetTimer(0, False);
    if (ActivePickup != None && !ActivePickup.bDeleteMe) ActivePickup.Destroy();
    ActivePickup = None;
    if (ActiveSavePoint != None && !ActiveSavePoint.bDeleteMe) ActiveSavePoint.Destroy();
    ActiveSavePoint = None;
    Log("[MP_PROBE] probe=pickup status=" $ Result $ " phase=" $ Phase
        $ " events=" $ TotalEvents $ " reason=" $ Reason);
    Destroy();
}

function bool HasReadyPair()
{
    local byte I;
    local HPCoopHarry H;
    if (Game == None || Game.bDeleteMe || Game.bWaitingForPlayers
        || Game.CampaignState == None || !Game.CampaignState.bIsTestStage
        || !Game.CampaignState.IsSnapshotReady() || Game.bCoopRecoveryBlocked)
        return False;
    for (I = 0; I < 2; I++)
    {
        H = Game.CoopPlayers[I];
        if (!Game.IsAliveCoopPlayer(H) || Game.ReadyPlayers[I] == 0
            || H.Player == None || Viewport(H.Player) != None || H.bCoopAwaitResume)
            return False;
        if (Players[I] != None && Players[I] != H) return False;
    }
    return Game.CoopPlayers[0] != Game.CoopPlayers[1];
}

function bool StablePlayers()
{
    local byte I;
    local HPCoopHarry H;
    if (!HasReadyPair() || Game.bStoryCaptured) return False;
    for (I = 0; I < 2; I++)
    {
        H = Game.CoopPlayers[I];
        if (!H.IsInState('PlayerWalking') || H.Physics != PHYS_Walking
            || (H.Base != None && H.Base != Level) || H.bIsCaptured
            || H.bCoopStoryCaptured || H.bCoopPotionPending || H.CarryingActor != None
            || VSize(H.Velocity) > 1 || VSize(H.Acceleration) > 1
            || H.Region.Zone == None || H.Region.Zone.bKillZone
            || H.Region.Zone.bPainZone || H.Region.Zone.bWaterZone
            || H.Region.Zone.bTortureZone) return False;
        if (bSeeded && VSize(H.Location - PlayerPositions[I]) > 2) return False;
    }
    return True;
}

function bool CountsMatch()
{
    local byte I;
    for (I = 0; I < 2; I++)
        if (Players[I] == None || Players[I].bDeleteMe || Potions[I] == None
            || Players[I].GetHealthCount() != ExpectedHealth[I]
            || Potions[I].nCount != ExpectedPotions[I]) return False;
    return True;
}

function bool SeedFixture()
{
    local byte I;
    if (!StablePlayers()) return False;
    for (I = 0; I < 2; I++)
    {
        Players[I] = Game.CoopPlayers[I];
        if (Players[I].managerStatus == None || Players[I].GetHealthStatusItem() == None
            || Players[I].GetHealthStatusItem().nCurrCountPotential != 100) return False;
        Potions[I] = Players[I].managerStatus.GetStatusItem(
            Class'StatusGroupPotions', Class'StatusItemWiggenwell');
        if (Potions[I] == None) return False;
    }
    for (I = 0; I < 2; I++)
    {
        PlayerPositions[I] = Players[I].Location;
        Players[I].bAutoQuaff = False;
        Players[I].SetHealth(20);
        Potions[I].SetCount(0);
        ExpectedHealth[I] = 20;
        ExpectedPotions[I] = 0;
        Players[I].PublishCoopStatus(True);
    }
    bSeeded = True;
    Log("[MP_PROBE] probe=pickup fixture=seeded health=20,20 potions=0,0 disposable=True");
    return CountsMatch();
}

function bool BoxOverlaps(BoundingBox A, BoundingBox B)
{
    return A.Min.X < B.Max.X && A.Max.X > B.Min.X
        && A.Min.Y < B.Max.Y && A.Max.Y > B.Min.Y
        && A.Min.Z < B.Max.Z && A.Max.Z > B.Min.Z;
}

// Conservative swept box excludes every other actor except source-audited
// passive music/finished-scene volumes. The real target pawn remains in place.
function bool IsClearSweep(HPCoopHarry H, vector Start, vector End, vector Extent,
    optional Actor IgnoreProp)
{
    local Actor A;
    local vector HitLocation, HitNormal;
    local BoundingBox Sweep, OtherBox;
    if (!SetLocation(Start) || Region.Zone == None || Region.Zone.bKillZone
        || Region.Zone.bPainZone || Region.Zone.bWaterZone || Region.Zone.bTortureZone)
        return False;
    if (H.Trace(HitLocation, HitNormal, End, Start, False, Extent) != None) return False;
    Sweep.Min.X = FMin(Start.X, End.X) - Extent.X - 2;
    Sweep.Min.Y = FMin(Start.Y, End.Y) - Extent.Y - 2;
    Sweep.Min.Z = FMin(Start.Z, End.Z) - Extent.Z - 2;
    Sweep.Max.X = FMax(Start.X, End.X) + Extent.X + 2;
    Sweep.Max.Y = FMax(Start.Y, End.Y) + Extent.Y + 2;
    Sweep.Max.Z = FMax(Start.Z, End.Z) + Extent.Z + 2;
    foreach AllActors(Class'Actor', A)
        if (A != self && A != Level && A != H && A != IgnoreProp
            && !A.bDeleteMe && A.bCollideActors && !Game.IsPassiveCoopOverlap(A))
        {
            OtherBox = A.GetWorldCollisionBox();
            if (OtherBox.IsValid == 0 || BoxOverlaps(Sweep, OtherBox)) return False;
        }
    return True;
}

function HProp CreateFixtureProp(byte Slot, bool bPotion, out vector Start)
{
    local Class<HProp> PropClass;
    local HProp P;
    local HPCoopHarry H;
    local int I;
    local vector Candidate, Extent;
    local rotator Direction;
    local BoundingBox ActualBox;
    H = Players[Slot];
    if (bPotion) PropClass = Class'WWellBlueBottle';
    else PropClass = Class'ChocolateFrog';
    Extent.X = PropClass.Default.CollisionRadius;
    Extent.Y = Extent.X;
    Extent.Z = PropClass.Default.CollisionHeight;
    for (I = 0; I < 8; I++)
    {
        Direction = H.Rotation;
        Direction.Pitch = 0;
        Direction.Roll = 0;
        Direction.Yaw += I * 8192;
        Candidate = H.Location + vector(Direction) * (H.CollisionRadius + Extent.X + 32);
        if (!IsClearSweep(H, Candidate, H.Location, Extent)) continue;
        P = Spawn(PropClass, self,, Candidate, Direction);
        if (P == None) continue;
        // Freeze only this synthetic prop's random hopping/falling. Keep the
        // original class, Touch, pickup flags, dimensions and native collision.
        P.GotoState('');
        P.SetTimer(0, False);
        P.Disable('Tick');
        P.SetPhysics(PHYS_None);
        P.Velocity = vect(0,0,0);
        P.Acceleration = vect(0,0,0);
        ActualBox = P.GetWorldCollisionBox();
        if (P.bDeleteMe || P.bHidden || !P.bCollideActors || !P.bPickupOnTouch
            || P.bCoopPickupClaimed || VSize(P.Location - Candidate) > 1
            || ActualBox.IsValid == 0)
        {
            P.Destroy();
            continue;
        }
        // Include asymmetric primitive offsets in the conservative sweep.
        Extent.X = FMax(Abs(ActualBox.Min.X - P.Location.X), Abs(ActualBox.Max.X - P.Location.X));
        Extent.Y = FMax(Abs(ActualBox.Min.Y - P.Location.Y), Abs(ActualBox.Max.Y - P.Location.Y));
        Extent.Z = FMax(Abs(ActualBox.Min.Z - P.Location.Z), Abs(ActualBox.Max.Z - P.Location.Z));
        if (!IsClearSweep(H, P.Location, H.Location, Extent, P))
        {
            P.Destroy();
            continue;
        }
        P.EventToSendOnPickup = Tag;
        Start = P.Location;
        return P;
    }
    return None;
}

function bool HasNativeContact(HProp P, HPCoopHarry H)
{
    local HPCoopHarry A;
    if (P == None || P.bDeleteMe) return False;
    foreach P.TouchingActors(Class'HPCoopHarry', A)
        if (A == H) return True;
    return False;
}

// Observes the original post-award event, never grants an item or invokes Touch.
event Trigger(Actor Other, Pawn EventInstigator)
{
    if (!bArmed || bFinished) return;
    StepEvents++;
    TotalEvents++;
    if (Other != ActivePickup || EventInstigator != ActivePickup
        || ActivePickup == None || !ActivePickup.bCoopPickupClaimed
        || ActivePickup.PlayerHarry != OriginalPickupContext)
        bEventContractOK = False;
}

// Gate 1/2 deliberately changes a server flag synchronously around real native
// contact, then restores it before any world tick/replication frame. This tests
// the refusal predicate, not real death presentation or a cutscene transition.
function bool CollectStep(byte Slot, bool bPotion, optional byte Gate)
{
    local HProp P;
    local HPCoopHarry H;
    local vector Start;
    local bool WasDead, WasCaptured, bContact;
    local int Attempt;
    local string PropName;
    if (!StablePlayers() || !CountsMatch())
    {
        Finish("BLOCKED", "players-moved-or-fixture-status-changed");
        return False;
    }
    H = Players[Slot];
    P = CreateFixtureProp(Slot, bPotion, Start);
    if (P == None)
    {
        Finish("BLOCKED", "no-safe-native-contact-path");
        return False;
    }
    ActivePickup = P;
    OriginalPickupContext = P.PlayerHarry;
    PropName = string(P);
    StepEvents = 0;
    bEventContractOK = True;
    if (Gate != 0)
        for (Attempt = 0; Attempt < 2; Attempt++)
        {
            WasDead = H.bCoopDead;
            WasCaptured = H.bCoopStoryCaptured;
            if (Gate == 1) H.bCoopDead = True;
            if (Gate == 2) H.bCoopStoryCaptured = True;
            P.MoveSmooth(H.Location - P.Location);
            bContact = HasNativeContact(P, H);
            H.bCoopDead = WasDead;
            H.bCoopStoryCaptured = WasCaptured;
            if (P == None || P.bDeleteMe || P.bCoopPickupClaimed || P.bHidden
                || StepEvents != 0 || !CountsMatch())
            {
                Finish("FAIL", "refused-gate-consumed-or-awarded");
                return False;
            }
            if (!bContact)
            {
                Finish("BLOCKED", "refusal-has-no-native-touching-pair");
                return False;
            }
            Log("[MP_PROBE] probe=pickup check=PASS phase=" $ Phase $ " slot=" $ Slot
                $ " gate=" $ Gate $ " attempt=" $ Attempt $ " native-contact=True refused=True consumed=False");
            P.MoveSmooth(Start - P.Location);
            if (VSize(P.Location - Start) > 1 || HasNativeContact(P, H))
            {
                Finish("BLOCKED", "fixture-cannot-leave-contact-for-retry");
                return False;
            }
        }

    if (bPotion) ExpectedPotions[Slot]++;
    else ExpectedHealth[Slot] = Min(100, ExpectedHealth[Slot] + 40);
    P.MoveSmooth(H.Location - P.Location);
    if (StepEvents == 0)
    {
        Finish("BLOCKED", "native-contact-did-not-produce-original-pickup-event");
        return False;
    }
    if (StepEvents != 1 || !bEventContractOK || !CountsMatch()
        || (P != None && (!P.bDeleteMe || !P.bCoopPickupClaimed)))
    {
        Finish("FAIL", "award-recipient-count-event-or-destruction-contract");
        return False;
    }
    ActivePickup = None;
    Log("[MP_PROBE] probe=pickup check=PASS phase=" $ Phase $ " slot=" $ Slot
        $ " prop=" $ PropName $ " potion=" $ bPotion $ " event-count=1 native-contact-award=True"
        $ " health=" $ ExpectedHealth[0] $ "," $ ExpectedHealth[1]
        $ " potions=" $ ExpectedPotions[0] $ "," $ ExpectedPotions[1]
        $ " original-context-unchanged=True destroyed=True");
    return True;
}

// Exact original SavePoint contact test, appended after the six pickup cases.
// These functions need IsClearSweep's optional ignored parameter typed Actor.
function SavePoint CreateFixtureSavePoint(byte Slot, out vector Start)
{
    local HPCoopHarry H;
    local SavePoint S;
    local int I;
    local vector Candidate, Extent;
    local rotator Direction;
    local BoundingBox Box;
    H = Players[Slot];
    Extent.X = Class'SavePoint'.Default.CollisionRadius;
    Extent.Y = Extent.X;
    Extent.Z = Class'SavePoint'.Default.CollisionHeight;
    for (I = 0; I < 8; I++)
    {
        Direction = H.Rotation;
        Direction.Pitch = 0;
        Direction.Roll = 0;
        Direction.Yaw += I * 8192;
        Candidate = H.Location + vector(Direction) * (H.CollisionRadius + Extent.X + 32);
        if (!IsClearSweep(H, Candidate, H.Location, Extent)) continue;
        S = Spawn(Class'SavePoint', self,, Candidate, Class'SavePoint'.Default.Rotation);
        if (S == None) continue;
        // This is an explicitly active one-shot synthetic book. Freeze its
        // bobbing only so repeated native contact has a deterministic path.
        S.GotoState('');
        S.Disable('Tick');
        S.SetTimer(0, False);
        S.SetPhysics(PHYS_None);
        S.Velocity = vect(0,0,0);
        S.Acceleration = vect(0,0,0);
        S.bActive = True;
        Box = S.GetWorldCollisionBox();
        if (S.Class != Class'SavePoint' || S.bDeleteMe || S.bHidden || !S.bSaveOnce
            || !S.bCollideActors || S.Opacity <= 0 || Box.IsValid == 0
            || VSize(S.Location - Candidate) > 1 || Game.StoryLeader == None
            || S.PlayerHarry != Game.StoryLeader || Level.PlayerHarryActor != Game.StoryLeader)
        {
            S.Destroy();
            continue;
        }
        Extent.X = FMax(Abs(Box.Min.X - S.Location.X), Abs(Box.Max.X - S.Location.X));
        Extent.Y = FMax(Abs(Box.Min.Y - S.Location.Y), Abs(Box.Max.Y - S.Location.Y));
        Extent.Z = FMax(Abs(Box.Min.Z - S.Location.Z), Abs(Box.Max.Z - S.Location.Z));
        if (!IsClearSweep(H, S.Location, H.Location, Extent, S))
        {
            S.Destroy();
            continue;
        }
        Start = S.Location;
        return S;
    }
    return None;
}

function CaptureSavePointSnapshot(SavePoint S)
{
    ActiveSavePoint = S;
    bHaveSavePointSnapshot = True;
    SavePointContext = S.PlayerHarry;
    SavedBookActive = S.bActive;
    SavedBookSaveOnce = S.bSaveOnce;
    SavedBookHidden = S.bHidden;
    SavedBookCollideActors = S.bCollideActors;
    SavedBookBlockActors = S.bBlockActors;
    SavedBookBlockPlayers = S.bBlockPlayers;
    SavedBookCollideWorld = S.bCollideWorld;
    SavedBookWait = S.fWaitTime;
    SavedBookOpacity = S.Opacity;
    SavedBookPauser = Level.Pauser;
    SavedBookDilation = Level.TimeDilation;
    SavedBookEventCount = TotalEvents;
}

function bool SavePointSnapshotUnchanged()
{
    local SavePoint S;
    S = ActiveSavePoint;
    if (!bHaveSavePointSnapshot || S == None || S.bDeleteMe
        || S.Class != Class'SavePoint' || S.PlayerHarry != SavePointContext
        || SavePointContext != Game.StoryLeader || Level.PlayerHarryActor != SavePointContext)
        return False;
    return S.bActive == SavedBookActive && S.bSaveOnce == SavedBookSaveOnce
        && S.bHidden == SavedBookHidden && S.bCollideActors == SavedBookCollideActors
        && S.bBlockActors == SavedBookBlockActors && S.bBlockPlayers == SavedBookBlockPlayers
        && S.bCollideWorld == SavedBookCollideWorld
        && Abs(S.fWaitTime - SavedBookWait) < 0.0001
        && Abs(S.Opacity - SavedBookOpacity) < 0.0001
        && Level.Pauser == SavedBookPauser
        && Abs(Level.TimeDilation - SavedBookDilation) < 0.0001
        && !Players[0].bQueuedToSaveGame && !Players[1].bQueuedToSaveGame
        && TotalEvents == SavedBookEventCount && CountsMatch();
}

function bool HasNativeSavePointContact(SavePoint S, HPCoopHarry H)
{
    local HPCoopHarry A;
    if (S == None || S.bDeleteMe) return False;
    foreach S.TouchingActors(Class'HPCoopHarry', A)
        if (A == H) return True;
    return False;
}

function bool VerifyPreviousSavePoint()
{
    if (!bHaveSavePointSnapshot) return True;
    if (!SavePointSnapshotUnchanged())
    {
        Finish("FAIL", "savepoint-late-mutation-or-save-queue");
        return False;
    }
    Log("[MP_PROBE] probe=savepoint check=PASS phase=" $ Phase
        $ " book=" $ ActiveSavePoint $ " delayed-unchanged=True cleanup=fixture-only");
    // The book was proved intact before test cleanup. No placed book is used.
    ActiveSavePoint.Destroy();
    ActiveSavePoint = None;
    bHaveSavePointSnapshot = False;
    return True;
}

function bool SavePointContactStep(byte Slot)
{
    local SavePoint S;
    local HPCoopHarry H;
    local vector Start;
    local int Attempt;
    if (!VerifyPreviousSavePoint()) return False;
    if (!StablePlayers() || !CountsMatch() || Players[0].bQueuedToSaveGame
        || Players[1].bQueuedToSaveGame)
    {
        Finish("BLOCKED", "savepoint-fixture-not-stable-or-existing-save-queue");
        return False;
    }
    H = Players[Slot];
    S = CreateFixtureSavePoint(Slot, Start);
    if (S == None)
    {
        Finish("BLOCKED", "savepoint-no-safe-native-contact-path-or-canonical-context");
        return False;
    }
    CaptureSavePointSnapshot(S);
    for (Attempt = 0; Attempt < 2; Attempt++)
    {
        // Do not call SavePoint.Touch or OnSaveGame, even for this fixture.
        S.MoveSmooth(H.Location - S.Location);
        if (!SavePointSnapshotUnchanged())
        {
            Finish("FAIL", "savepoint-contact-mutated-book-status-or-queue");
            return False;
        }
        if (!HasNativeSavePointContact(S, H))
        {
            Finish("BLOCKED", "savepoint-no-native-touching-pair");
            return False;
        }
        Log("[MP_PROBE] probe=savepoint check=PASS phase=" $ Phase $ " slot=" $ Slot
            $ " attempt=" $ Attempt $ " book=" $ S $ " toucher=" $ H
            $ " native-contact=True active=" $ S.bActive $ " save-once=" $ S.bSaveOnce
            $ " wait=" $ S.fWaitTime $ " opacity=" $ S.Opacity $ " hidden=" $ S.bHidden
            $ " deleted=" $ S.bDeleteMe $ " collide=" $ S.bCollideActors
            $ " block-actors=" $ S.bBlockActors $ " block-players=" $ S.bBlockPlayers
            $ " collide-world=" $ S.bCollideWorld $ " canonical=" $ S.PlayerHarry
            $ " health-potions-unchanged=True save-queued=False checkpoint=False");
        S.MoveSmooth(Start - S.Location);
        if (!SavePointSnapshotUnchanged() || VSize(S.Location - Start) > 1
            || HasNativeSavePointContact(S, H))
        {
            Finish("BLOCKED", "savepoint-cannot-separate-for-fresh-contact");
            return False;
        }
    }
    // Retain the book until the next scheduled step verifies no late mutation.
    return True;
}

event Timer()
{
    if (!bArmed || bFinished) return;
    if (!bPairReadySeen)
    {
        if (!HasReadyPair()) return;
        bPairReadySeen = True;
        Deadline = Level.TimeSeconds + 180;
    }
    if (Level.TimeSeconds > Deadline)
    {
        Finish("BLOCKED", "game-time-timeout-after-ready-pair");
        return;
    }
    if (Phase == 0)
    {
        if (Game.bStoryCaptured) { bSawIntro = True; return; }
        if (!bSawIntro || Game.StoryView == None || Game.StoryView.SceneSerial < 1) return;
        if (!SeedFixture()) return;
        Phase = 1;
        NextStep = Level.TimeSeconds + 0.5;
        return;
    }
    if (Level.TimeSeconds < NextStep) return;
    if (!StablePlayers() || !CountsMatch())
    {
        Finish("FAIL", "late-duplicate-or-unexpected-owner-status-or-movement");
        return;
    }
    switch (Phase)
    {
    case 1: if (!CollectStep(0, False)) return; break;
    case 2: if (!CollectStep(1, False)) return; break;
    case 3: if (!CollectStep(0, True)) return; break;
    case 4: if (!CollectStep(1, True)) return; break;
    case 5: if (!CollectStep(0, False, 1)) return; break;
    case 6: if (!CollectStep(1, True, 2)) return; break;
    case 7: if (!SavePointContactStep(0)) return; break;
    case 8: if (!SavePointContactStep(1)) return; break;
    case 9:
        if (!VerifyPreviousSavePoint()) return;
        if (TotalEvents != 6)
            Finish("FAIL", "expected-six-single-commit-events");
        else
            Finish("PASS", "synthetic-pickup-and-savepoint-guard-contact-only; checkpoint-native-frontend-placed-map-visual-input-two-pc-concurrent-race-NOT-PROVEN; discard-fixture-session");
        return;
    }
    Phase++;
    NextStep = Level.TimeSeconds + 0.5;
}

event Destroyed()
{
    if (ActivePickup != None && !ActivePickup.bDeleteMe) ActivePickup.Destroy();
    if (ActiveSavePoint != None && !ActiveSavePoint.bDeleteMe) ActiveSavePoint.Destroy();
    Super.Destroyed();
}

defaultproperties
{
    Tag=HPCoopPickupFixtureEvent
    RemoteRole=ROLE_None
    bHidden=True
    bCollideActors=False
    bCollideWorld=False
}
