// Explicit diagnostic fixture only. Never spawned by ordinary co-op gameplay.
// Tests the existing authority cast validator and original spell collision path;
// it is not a player-input, rendered-output or two-physical-PC acceptance test.
class HPCoopLumosProbe extends Actor;

var bool bOptIn, bArmed, bFinished, bSawIntroCapture;
var bool bPairReadySeen;
var HPCoopGame CoopGame;
var HPCoopHarry Casters[2];
var HPCoopWand Wands[2];
var gargoyle Targets[2];
var LumosLight Lights[2];
var string SpellNames[2];
var float AcceptedCastTimes[2];
var byte ObservedHit[2];
var int Phase;
var float Deadline, ReleaseSeenAt, SecondExpiryAt;

// Root integration: spawn on authority while the intro is still pending,
// set bOptIn=True only for the explicit launch option, then call Arm(Game).
// Spawning alone never starts the probe. A missed capture produces BLOCKED.
function bool Arm(HPCoopGame G)
{
    if (!bOptIn || bArmed || bFinished || Role != ROLE_Authority
        || Level.NetMode != NM_DedicatedServer || G == None || G != Level.Game
        || !(string(Level.Outer.Name) ~= "Ch1Rictusempra")
        || !(G.TestStage ~= "RictusempraLessonComplete"))
        return False;
    CoopGame = G;
    bArmed = True;
    Deadline = Level.TimeSeconds + 120;
    Phase = 0;
    SetTimer(0.1, True);
    Log("[MP_PROBE] probe=lumos status=ARMED mode=authority-fixture input-test=False visual-test=False two-pc=False");
    return True;
}

function bool HasReadyPair()
{
    local byte I;
    if (CoopGame == None || CoopGame.bDeleteMe || CoopGame.bWaitingForPlayers)
        return False;
    if (CoopGame.CampaignState == None || !CoopGame.CampaignState.bIsTestStage
        || !CoopGame.CampaignState.IsSnapshotReady()) return False;
    for (I = 0; I < 2; I++)
    {
        if (!CoopGame.IsAliveCoopPlayer(CoopGame.CoopPlayers[I])
            || CoopGame.ReadyPlayers[I] == 0
            || CoopGame.CoopPlayers[I].Player == None
            || Viewport(CoopGame.CoopPlayers[I].Player) != None)
            return False;
        if (Casters[I] != None && Casters[I] != CoopGame.CoopPlayers[I]) return False;
    }
    return CoopGame.CoopPlayers[0] != CoopGame.CoopPlayers[1];
}

function bool PrepareActors()
{
    local gargoyle G;
    local byte I;
    local spellLumos Existing;
    if (!HasReadyPair()) return False;
    foreach AllActors(Class'spellLumos', Existing)
        if (!Existing.bDeleteMe) return False;
    foreach AllActors(Class'gargoyle', G)
    {
        // These are actual map exports, not spawned substitutes.
        if (G.Class != Class'gargoyle' || !G.bStatic) continue;
        if (G.Name == 'gargoyle0') Targets[0] = G;
        if (G.Name == 'gargoyle3') Targets[1] = G;
    }
    for (I = 0; I < 2; I++)
    {
        Casters[I] = CoopGame.CoopPlayers[I];
        Wands[I] = HPCoopWand(Casters[I].Weapon);
        if (Wands[I] == None || Wands[I].Owner != Casters[I]
            || Targets[I] == None || Targets[I].bDeleteMe || Targets[I].bHidden
            || Targets[I].bMakeLumosInfinite || Targets[I].IsInState('Green')
            || !Targets[I].bProjTarget || !Targets[I].bCollideActors
            || Targets[I].eVulnerableToSpell != SPELL_Lumos
            || !Casters[I].IsInSpellBook(SPELL_Lumos) || Wands[I].IsLumosOn())
            return False;
        Lights[I] = Wands[I].TheLumosLight;
        if (Lights[I] == None || Lights[I].Owner != Wands[I]
            || Lights[I].PlayerHarry != Casters[I] || Lights[I].bInfiniteLumos
            || Abs(Lights[I].fLumosTimeToTurnOff - 30) > 0.01)
            return False;
    }
    return Lights[0] != Lights[1];
}

// Preflight a passive query actor before moving the real pawn. No world actor
// or trigger is disabled to manufacture a candidate. Static BSP floor only.
function bool IsClearPosition(HPCoopHarry H, vector Position)
{
    local vector Extent, HitLocation, HitNormal;
    local Actor A;
    local BoundingBox PawnBox, OtherBox;
    Extent.X = H.CollisionRadius;
    Extent.Y = H.CollisionRadius;
    Extent.Z = H.CollisionHeight;
    if (!SetLocation(Position) || Region.Zone == None || Region.Zone.bKillZone
        || Region.Zone.bPainZone || Region.Zone.bWaterZone) return False;
    if (!H.CanFit(H.CollisionRadius, H.CollisionHeight, H.CollisionWidth, Position, H.Rotation))
        return False;
    // Ignore this pawn in the overlap trace by tracing from the pawn itself.
    // A grounded pawn can exactly touch the floor. The upward clearance sweep
    // must not classify this ordinary floor contact as penetration. The final
    // real-pawn SetLocation still checks its full cylinder at the exact point.
    if (H.Trace(HitLocation, HitNormal, Position + vect(0,0,3), Position + vect(0,0,2), True, Extent) != None)
        return False;
    PawnBox = H.GetWorldCollisionBox();
    if (PawnBox.IsValid == 0) return False;
    PawnBox.Min += Position - H.Location - vect(2,2,2);
    PawnBox.Max += Position - H.Location + vect(2,2,2);
    // M212 exposes AllActors, not the UT CollidingActors iterator. Native world
    // collision boxes cover nonblocking trigger shapes and vertical offsets too.
    foreach AllActors(Class'Actor', A)
        if (A != H && A != Level && A != self && A.bCollideActors
            && !CoopGame.IsPassiveCoopOverlap(A))
        {
            OtherBox = A.GetWorldCollisionBox();
            if (OtherBox.IsValid == 0) return False;
            if (OtherBox.Min.X < PawnBox.Max.X && OtherBox.Max.X > PawnBox.Min.X
                && OtherBox.Min.Y < PawnBox.Max.Y && OtherBox.Max.Y > PawnBox.Min.Y
                && OtherBox.Min.Z < PawnBox.Max.Z && OtherBox.Max.Z > PawnBox.Min.Z)
                return False;
        }
    return True;
}

function bool FindCastPosition(byte Slot, out vector Position, out rotator Facing)
{
    local int Ring, I;
    local vector Top, Bottom, HitLocation, HitNormal, Extent, SpellExtent, Candidate, Muzzle, Chest;
    local rotator Direction, Flat;
    local Actor A;
    local HPCoopHarry H;
    local gargoyle Target;
    H = Casters[Slot];
    Target = Targets[Slot];
    Extent.X = H.CollisionRadius;
    Extent.Y = H.CollisionRadius;
    Extent.Z = 0;
    SpellExtent.X = Class'spellLumos'.Default.CollisionRadius;
    SpellExtent.Y = SpellExtent.X;
    SpellExtent.Z = Class'spellLumos'.Default.CollisionHeight;
    for (Ring = 0; Ring < 3; Ring++)
        for (I = 0; I < 16; I++)
        {
            Direction = Target.Rotation;
            Direction.Pitch = 0;
            Direction.Roll = 0;
            Direction.Yaw += I * 4096;
            Candidate = Target.Location + vector(Direction) * (160 + Ring * 80);
            Top = Candidate + vect(0,0,192);
            Bottom = Candidate - vect(0,0,256);
            A = Trace(HitLocation, HitNormal, Bottom, Top, True, Extent);
            if (A != Level || HitNormal.Z < 0.7) continue;
            Candidate = HitLocation + vect(0,0,1) * (H.CollisionHeight + 2);
            if (!IsClearPosition(H, Candidate)) continue;
            Facing = rotator(Target.Location - Candidate);
            Flat = Facing;
            Flat.Pitch = 0;
            Flat.Roll = 0;
            Muzzle = Candidate + vector(Flat) * (H.CollisionRadius + 8);
            Muzzle.Z += H.CollisionHeight * 0.5;
            Chest = Candidate;
            Chest.Z += H.CollisionHeight * 0.5;
            // A visible point is insufficient at a BSP corner: the original
            // projectile has a nonzero collision extent and can hit that wall.
            if (H.Trace(HitLocation, HitNormal, Muzzle, Chest, True, SpellExtent) != None) continue;
            A = H.Trace(HitLocation, HitNormal, Target.Location, Muzzle, True, SpellExtent);
            if (A != None && A != Target) continue;
            if (VSize(Target.Location - Muzzle) > Class'SpellCursor'.Default.fLOS_Distance * 1.25)
                continue;
            Facing = rotator(Target.Location - Muzzle);
            Position = Candidate;
            return True;
        }
    return False;
}

function bool CastAndRestore(byte Slot)
{
    local HPCoopHarry H;
    local vector Candidate, OriginalPosition, OriginalVelocity, OriginalAcceleration;
    local rotator Facing, OriginalFacing, OriginalView;
    local Actor OriginalBase;
    local baseSpell Previous, S;
    local bool bRestored, bAccepted;
    H = Casters[Slot];
    if (!HasReadyPair() || CoopGame.bStoryCaptured || H.bIsCaptured
        || !H.IsInState('PlayerWalking') || H.Physics != PHYS_Walking
        || !H.bCanCast || H.CarryingActor != None || H.bInDuelingMode
        || H.bHarryUsingSword || (H.Base != None && H.Base != Level)
        || Level.TimeSeconds < H.NextCoopCastTime
        || VSize(H.Velocity) > 1 || VSize(H.Acceleration) > 1)
    {
        FinishProbe("BLOCKED", "caster-not-idle-and-castable");
        return False;
    }
    OriginalPosition = H.Location;
    OriginalFacing = H.Rotation;
    OriginalView = H.ViewRotation;
    OriginalVelocity = H.Velocity;
    OriginalAcceleration = H.Acceleration;
    OriginalBase = H.Base;
    if (!IsClearPosition(H, OriginalPosition) || !FindCastPosition(Slot, Candidate, Facing))
    {
        FinishProbe("BLOCKED", "no-clear-floor-los-candidate-or-return-position");
        return False;
    }
    // Authority execution is synchronous: restore the pawn in this same call,
    // before another movement packet or replication frame can observe the warp.
    // No capture/input flag or validator condition is relaxed for the cast.
    if (!H.SetLocation(Candidate))
    {
        FinishProbe("BLOCKED", "validated-candidate-setlocation-failed");
        return False;
    }
    bAccepted = False;
    if (VSize(H.Location - Candidate) <= 1 && H.IsInState('PlayerWalking')
        && !H.HarryIsDead() && H.Region.Zone != None && !H.Region.Zone.bKillZone
        && !H.Region.Zone.bPainZone && !H.Region.Zone.bWaterZone)
    {
        H.SetRotation(Facing);
        H.ViewRotation = Facing;
        Previous = Wands[Slot].LastCastedSpell;
        H.ServerCastCoopSpell(Targets[Slot], vect(0,0,0));
        S = Wands[Slot].LastCastedSpell;
        bAccepted = S != None && S != Previous && S.Class == Class'spellLumos'
            && S.Owner == H && S.Instigator == H && S.PlayerHarry == H
            && S.SpellWand == Wands[Slot] && S.TargetActor == Targets[Slot];
        if (bAccepted)
        {
            // Existing opt-in flag enables contact/destruction diagnostics only.
            S.SetDebugMode(True);
            SpellNames[Slot] = string(S);
            AcceptedCastTimes[Slot] = H.NextCoopCastTime;
        }
    }
    bRestored = H.SetLocation(OriginalPosition);
    H.SetRotation(OriginalFacing);
    H.ViewRotation = OriginalView;
    H.Velocity = OriginalVelocity;
    H.Acceleration = OriginalAcceleration;
    if (bRestored && VSize(H.Location - OriginalPosition) <= 1)
        H.SetBase(OriginalBase);
    else
    {
        // Keep the client consistent if native placement unexpectedly refuses
        // the previously checked return spot. Never force an unchecked teleport.
        H.ClientSetLocation(H.Location, H.Rotation);
        FinishProbe("BLOCKED", "return-setlocation-failed-pawn-remains-at-checked-candidate");
        return False;
    }
    if (!bAccepted)
    {
        FinishProbe("BLOCKED", "normal-validator-or-original-spawn-rejected");
        return False;
    }
    Log("[MP_PROBE] probe=lumos phase=original-spawn slot=" $ Slot
        $ " caster=" $ H $ " spell=" $ SpellNames[Slot] $ " target=" $ Targets[Slot]
        $ " candidate=" $ Candidate $ " restored=True request=ServerCastCoopSpell");
    return True;
}

function bool StableOwnership()
{
    local byte I;
    if (!HasReadyPair() || CoopGame.bStoryCaptured) return False;
    for (I = 0; I < 2; I++)
        if (Casters[I].Weapon != Wands[I] || Wands[I].bDeleteMe
            || Wands[I].TheLumosLight != Lights[I] || Lights[I].bDeleteMe
            || Lights[I].Owner != Wands[I] || Lights[I].PlayerHarry != Casters[I]
            || (AcceptedCastTimes[I] != 0 && Casters[I].NextCoopCastTime != AcceptedCastTimes[I]))
            return False;
    return True;
}

function bool ObserveOriginalHit(byte Slot)
{
    if (!Lights[Slot].bLumosOn || !Targets[Slot].IsInState('Green')) return False;
    ObservedHit[Slot] = 1;
    Log("[MP_PROBE] probe=lumos phase=hit-observed slot=" $ Slot
        $ " spell=" $ SpellNames[Slot] $ " target=" $ Targets[Slot]
        $ " target-state=" $ Targets[Slot].GetStateName() $ " light=" $ Lights[Slot]
        $ " light-owner=" $ Lights[Slot].Owner $ " light-player=" $ Lights[Slot].PlayerHarry
        $ " light-age=" $ Lights[Slot].fLumosTime);
    return True;
}

function Timer()
{
    if (!bArmed || bFinished) return;
    if (CoopGame == None || CoopGame.bDeleteMe)
    {
        FinishProbe("BLOCKED", "session-unavailable");
        return;
    }
    if (Phase == 0)
    {
        // Level.TimeSeconds advances during the waiting lobby on this M212.
        // The intro timeout starts when both real owner contexts are ready.
        if (!bPairReadySeen)
        {
            if (!HasReadyPair()) return;
            bPairReadySeen = True;
            Deadline = Level.TimeSeconds + 120;
        }
        if (CoopGame.bStoryCaptured) bSawIntroCapture = True;
        if (Level.TimeSeconds > Deadline)
        {
            FinishProbe("BLOCKED", "ready-pair-and-intro-release-timeout");
            return;
        }
        if (!bSawIntroCapture || CoopGame.bStoryCaptured || !HasReadyPair() || Level.Pauser != "") return;
        if (ReleaseSeenAt == 0) ReleaseSeenAt = Level.TimeSeconds;
        if (Level.TimeSeconds - ReleaseSeenAt < 1) return;
        if (!PrepareActors())
        {
            FinishProbe("BLOCKED", "map-target-or-finite-owner-light-baseline-invalid");
            return;
        }
        if (!CastAndRestore(0)) return;
        Phase = 1;
        Deadline = Level.TimeSeconds + 5;
        return;
    }
    if (!StableOwnership())
    {
        FinishProbe("BLOCKED", "disconnect-death-capture-owner-change-or-competing-cast");
        return;
    }
    if (Phase == 1 && ObserveOriginalHit(0))
    {
        if (Lights[1].bLumosOn)
        {
            FinishProbe("FAIL", "slot0-hit-also-activated-slot1");
            return;
        }
        if (!CastAndRestore(1)) return;
        Phase = 2;
        Deadline = Level.TimeSeconds + 5;
        return;
    }
    if (Phase == 2 && ObserveOriginalHit(1))
    {
        if (!Lights[0].bLumosOn || Lights[0] == Lights[1])
        {
            FinishProbe("FAIL", "two-independent-active-lights-not-observed");
            return;
        }
        SecondExpiryAt = Level.TimeSeconds + Lights[1].fLumosTimeToTurnOff - Lights[1].fLumosTime;
        Log("[MP_PROBE] probe=lumos phase=two-active slot0=True slot1=True distinct=True");
        Wands[0].DeactivateCoopLumos();
        if (Lights[0].bLumosOn || !Lights[1].bLumosOn)
        {
            FinishProbe("FAIL", "turnoff-not-isolated");
            return;
        }
        Log("[MP_PROBE] probe=lumos phase=slot0-off slot0=False slot1=True");
        Phase = 3;
        Deadline = SecondExpiryAt + 2;
        return;
    }
    if (Phase == 3)
    {
        if (Lights[0].bLumosOn)
        {
            FinishProbe("FAIL", "slot0-reenabled-without-probe-cast");
            return;
        }
        if (!Lights[1].bLumosOn)
        {
            if (Level.TimeSeconds < SecondExpiryAt - 0.25)
                FinishProbe("FAIL", "slot1-turned-off-before-original-expiry");
            else
                FinishProbe("PASS", "two-original-hits-isolated-off-and-original-30s-expiry");
            return;
        }
    }
    if (Level.TimeSeconds > Deadline)
        FinishProbe("FAIL", "original-hit-or-expiry-timeout");
}

function FinishProbe(string Status, string Reason)
{
    local byte I;
    if (bFinished) return;
    bFinished = True;
    SetTimer(0, False);
    // Only end our own observed activation when no subsequent cast intervened.
    // Never reset the gargoyle state or synthesize a hit to make a test pass.
    if (Status != "PASS")
        for (I = 0; I < 2; I++)
            if (ObservedHit[I] != 0 && Casters[I] != None && Wands[I] != None
                && !Casters[I].bDeleteMe && !Wands[I].bDeleteMe
                && Casters[I].NextCoopCastTime == AcceptedCastTimes[I])
                Wands[I].DeactivateCoopLumos();
    Log("[MP_PROBE] probe=lumos status=" $ Status $ " phase=" $ Phase
        $ " reason=" $ Reason $ " hit0=" $ ObservedHit[0] $ " hit1=" $ ObservedHit[1]
        $ " input-test=False visual-test=False two-pc=False");
}

defaultproperties
{
    bHidden=True
    RemoteRole=ROLE_None
    bCollideActors=False
    bCollideWorld=False
    bBlockActors=False
    bBlockPlayers=False
    bOptIn=False
}
