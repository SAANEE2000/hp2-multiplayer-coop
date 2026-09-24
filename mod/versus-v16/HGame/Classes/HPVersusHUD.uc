// Versus-only overlay on the original HP2 HUD. Match facts come from the
// server's replicated pawn, PRI and GRI; this class never awards points.
class HPVersusHUD extends HPHud;

var bool bShowVersusScores;
var bool bVersusHUDTextureLoadAttempted;
var Texture VersusWhiteTexture;
var Texture VersusSpellIcons[6];

simulated event PostBeginPlay()
{
    Super.PostBeginPlay();
    LoadVersusHUDTextures();
}

simulated function LoadVersusHUDTextures()
{
    if (bVersusHUDTextureLoadAttempted)
        return;
    bVersusHUDTextureLoadAttempted = True;

    if (VersusWhiteTexture == None)
        VersusWhiteTexture = Texture(DynamicLoadObject(
            "UWindow.WhiteTexture", Class'Texture'));

    // Reuse HP2 assets. The duel icons cover the first three spells; the
    // stock spell-shape textures cover the three adventure interactions.
    if (VersusSpellIcons[0] == None)
        VersusSpellIcons[0] = Texture(DynamicLoadObject(
            "HP2_Menu.Icons.HP2SpellRictusempraSelect", Class'Texture'));
    if (VersusSpellIcons[1] == None)
        VersusSpellIcons[1] = Texture(DynamicLoadObject(
            "HP2_Menu.Icons.HP2SpellMimblewimbleSelect", Class'Texture'));
    if (VersusSpellIcons[2] == None)
        VersusSpellIcons[2] = Texture(DynamicLoadObject(
            "HP2_Menu.Icons.HP2SpellExpelliarmusSelect", Class'Texture'));
    if (VersusSpellIcons[3] == None)
        VersusSpellIcons[3] = Texture(DynamicLoadObject(
            "SpellShapes.SpellFX.FlipendoWet1", Class'Texture'));
    if (VersusSpellIcons[4] == None)
        VersusSpellIcons[4] = Texture(DynamicLoadObject(
            "SpellShapes.SpellFX.AlohomoraWet1", Class'Texture'));
    if (VersusSpellIcons[5] == None)
        VersusSpellIcons[5] = Texture(DynamicLoadObject(
            "SpellShapes.SpellFX.SpongifyWet1", Class'Texture'));
}

simulated function DrawSolidRect(Canvas C, float X, float Y,
    float W, float H, byte R, byte G, byte B)
{
    if (VersusWhiteTexture == None || W <= 0.0 || H <= 0.0)
        return;

    C.Style = 1;
    C.DrawColor.R = R;
    C.DrawColor.G = G;
    C.DrawColor.B = B;
    C.DrawColor.A = 255;
    C.SetPos(X, Y);
    C.DrawTile(VersusWhiteTexture, W, H, 0.0, 0.0,
        VersusWhiteTexture.USize, VersusWhiteTexture.VSize);
}

simulated function DrawVersusTextTint(Canvas C, float X, float Y,
    string Message, byte R, byte G, byte B)
{
    C.DrawColor.R = 0;
    C.DrawColor.G = 0;
    C.DrawColor.B = 0;
    C.SetPos(X + 1, Y + 1);
    C.DrawText(Message, False);
    C.DrawColor.R = R;
    C.DrawColor.G = G;
    C.DrawColor.B = B;
    C.SetPos(X, Y);
    C.DrawText(Message, False);
}

simulated function DrawVersusText(Canvas C, float X, float Y, string Message)
{
    DrawVersusTextTint(C, X, Y, Message, 245, 238, 210);
}

simulated function string FormatVersusSeconds(float Seconds)
{
    local int Hundredths;
    local int Whole;
    local int Fraction;
    local string FractionText;

    if (Seconds < 0.0)
        Seconds = 0.0;
    Hundredths = int(Seconds * 100.0 + 0.99);
    Whole = Hundredths / 100;
    Fraction = Hundredths - Whole * 100;
    FractionText = string(Fraction);
    if (Fraction < 10)
        FractionText = "0" $ FractionText;
    return string(Whole) $ "." $ FractionText;
}

simulated function DrawVersusSpellIcon(Canvas C, byte SpellSlot,
    float X, float Y, float Size)
{
    local Texture Icon;

    if (SpellSlot > 5)
        return;
    Icon = VersusSpellIcons[SpellSlot];
    if (Icon == None)
        return;

    C.Style = 2;
    C.DrawColor.R = 255;
    C.DrawColor.G = 255;
    C.DrawColor.B = 255;
    C.DrawColor.A = 255;
    C.SetPos(X, Y);
    C.DrawTile(Icon, Size, Size, 0.0, 0.0, Icon.USize, Icon.VSize);
}

simulated function DrawVersusCombatPanel(Canvas C, HPVersusHarry H)
{
    local float Scale;
    local float X;
    local float Y;
    local float W;
    local float HealthFraction;
    local float CooldownLeft;
    local float LockLeft;
    local float DisarmLeft;
    local float SpeedLeft;
    local string StatusText;
    local string EffectText;
    local byte StatusR;
    local byte StatusG;
    local byte StatusB;
    local byte SpellSlot;

    Scale = FClamp(C.SizeY / 720.0, 0.75, 1.50);
    X = 18.0 * Scale;
    Y = C.SizeY - 156.0 * Scale;
    W = 342.0 * Scale;
    SpellSlot = H.SelectedVersusSpell;

    if (!bVersusHUDTextureLoadAttempted)
        LoadVersusHUDTextures();

    DrawSolidRect(C, X, Y, W, 138.0 * Scale, 19, 17, 28);
    DrawSolidRect(C, X, Y, W, 2.0 * Scale, 126, 103, 177);

    C.Font = C.SmallFont;
    DrawVersusTextTint(C, X + 12.0 * Scale, Y + 8.0 * Scale,
        "HP", 220, 205, 232);

    HealthFraction = FClamp(float(H.Health) / 100.0, 0.0, 1.0);
    DrawSolidRect(C, X + 12.0 * Scale, Y + 29.0 * Scale,
        220.0 * Scale, 13.0 * Scale, 55, 44, 61);
    DrawSolidRect(C, X + 14.0 * Scale, Y + 31.0 * Scale,
        216.0 * Scale * HealthFraction, 9.0 * Scale, 173, 45, 57);
    DrawVersusText(C, X + 242.0 * Scale, Y + 25.0 * Scale,
        string(Clamp(H.Health, 0, 100)) $ " / 100");

    DrawVersusTextTint(C, X + 12.0 * Scale, Y + 52.0 * Scale,
        "SELECTED SPELL", 220, 205, 232);
    DrawVersusSpellIcon(C, SpellSlot,
        X + 12.0 * Scale, Y + 74.0 * Scale, 50.0 * Scale);

    C.Font = C.MedFont;
    DrawVersusText(C, X + 72.0 * Scale, Y + 72.0 * Scale,
        Caps(H.GetVersusSpellName(SpellSlot)));

    CooldownLeft = H.VersusCooldownEndTime - Level.TimeSeconds;
    LockLeft = H.VersusSpellLockEndTime - Level.TimeSeconds;
    DisarmLeft = H.VersusDisarmEndTime - Level.TimeSeconds;
    StatusR = 116;
    StatusG = 231;
    StatusB = 141;
    if (DisarmLeft > 0.0)
    {
        StatusText = "DISARMED " $ FormatVersusSeconds(DisarmLeft);
        StatusR = 244;
        StatusG = 111;
        StatusB = 106;
    }
    else if (LockLeft > 0.0)
    {
        StatusText = "MUTED " $ FormatVersusSeconds(LockLeft);
        StatusR = 219;
        StatusG = 150;
        StatusB = 244;
    }
    else if (CooldownLeft > 0.0)
    {
        StatusText = "COOLDOWN " $ FormatVersusSeconds(CooldownLeft);
        StatusR = 245;
        StatusG = 190;
        StatusB = 88;
    }
    else
        StatusText = "READY";

    C.Font = C.SmallFont;
    DrawVersusTextTint(C, X + 72.0 * Scale, Y + 98.0 * Scale,
        StatusText, StatusR, StatusG, StatusB);

    SpeedLeft = H.VersusSpeedBoostEndTime - Level.TimeSeconds;
    if (H.VersusSpeedMultiplier > 1.01 && SpeedLeft > 0.0)
        EffectText = "SPEED x" $ string(H.VersusSpeedMultiplier)
            $ "  " $ string(int(SpeedLeft + 0.99)) $ "s";
    if (EffectText != "")
        DrawVersusTextTint(C, X + 72.0 * Scale, Y + 117.0 * Scale,
            EffectText, 109, 205, 255);
}

simulated function int GetSortedPlayers(out HPVersusPRI Rows[8])
{
    local HPVersusPRI P, Swap;
    local int Count, I, J;

    foreach AllActors(Class'HPVersusPRI', P)
    {
        if (P.bDeleteMe || P.PlayerName == "" || Count >= 8)
            continue;
        Rows[Count] = P;
        Count++;
    }

    for (I = 0; I < Count; I++)
        for (J = I + 1; J < Count; J++)
            if (Rows[J].RoundScore > Rows[I].RoundScore
                || (Rows[J].RoundScore == Rows[I].RoundScore
                    && Rows[J].PlayerID < Rows[I].PlayerID))
            {
                Swap = Rows[I];
                Rows[I] = Rows[J];
                Rows[J] = Swap;
            }
    return Count;
}

simulated function string FormatHideSeekClock(int Seconds)
{
    local int Minutes;
    local int Remainder;
    local string Tail;

    if (Seconds < 0)
        Seconds = 0;
    Minutes = Seconds / 60;
    Remainder = Seconds - Minutes * 60;
    if (Remainder < 10)
        Tail = "0" $ string(Remainder);
    else
        Tail = string(Remainder);
    return string(Minutes) $ ":" $ Tail;
}

simulated function HPVersusHarry FindPawnForPRI(HPVersusPRI WantedPRI)
{
    local HPVersusHarry H;

    foreach AllActors(Class'HPVersusHarry', H)
        if (H.PlayerReplicationInfo == WantedPRI)
            return H;
    return None;
}

simulated function DrawHideSeekOverlay(Canvas C, HPVersusHarry H,
    HPHideSeekGRI G, HPVersusPRI Rows[8], int Count)
{
    local float Scale;
    local float X;
    local float Y;
    local float W;
    local int I;
    local HPVersusHarry RowPawn;
    local string PhaseText;

    Scale = FClamp(C.SizeY / 720.0, 0.75, 1.50);
    X = 18.0 * Scale;
    Y = C.SizeY - 168.0 * Scale;
    W = 350.0 * Scale;
    DrawSolidRect(C, X, Y, W, 150.0 * Scale, 19, 17, 28);
    DrawSolidRect(C, X, Y, W, 2.0 * Scale, 126, 103, 177);

    if (G.HideSeekPhase == 'WaitingForPlayers')
        PhaseText = "WAITING FOR PLAYERS";
    else if (G.HideSeekPhase == 'SelectHunter')
        PhaseText = "SELECTING HUNTER";
    else if (G.HideSeekPhase == 'HidePhase')
        PhaseText = "HIDE PHASE";
    else if (G.HideSeekPhase == 'HuntPhase')
        PhaseText = "HUNT PHASE";
    else if (G.HideSeekPhase == 'RoundOver')
        PhaseText = "ROUND OVER";
    else
        PhaseText = "NEXT ROUND";

    C.Font = C.MedFont;
    DrawVersusTextTint(C, X + 12.0 * Scale, Y + 10.0 * Scale,
        PhaseText, 230, 215, 255);
    C.Font = C.SmallFont;
    DrawVersusText(C, X + 12.0 * Scale, Y + 40.0 * Scale,
        "TIME  " $ FormatHideSeekClock(G.RoundTimer));
    DrawVersusText(C, X + 180.0 * Scale, Y + 40.0 * Scale,
        "HIDERS LEFT  " $ string(G.HidersLeft));
    DrawVersusTextTint(C, X + 12.0 * Scale, Y + 66.0 * Scale,
        "ROLE  " $ H.GetHideSeekRoleName(), 116, 231, 141);

    if (H.bHideSeekCaught)
    {
        DrawVersusTextTint(C, X + 12.0 * Scale, Y + 94.0 * Scale,
            "FOUND - WAIT FOR NEXT ROUND", 244, 111, 106);
    }
    else if (H.HideSeekRole == 1)
    {
        DrawVersusText(C, X + 12.0 * Scale, Y + 94.0 * Scale,
            "SPELL  RICTUSEMPRA");
        if (G.HideSeekPhase == 'HuntPhase')
            DrawVersusTextTint(C, X + 12.0 * Scale, Y + 119.0 * Scale,
                "READY", 116, 231, 141);
        else
            DrawVersusTextTint(C, X + 12.0 * Scale, Y + 119.0 * Scale,
                "WAIT...", 245, 190, 88);
    }
    else
    {
        DrawVersusText(C, X + 12.0 * Scale, Y + 94.0 * Scale,
            "DISGUISE  " $ H.GetHideSeekDisguiseName());
        DrawVersusTextTint(C, X + 12.0 * Scale, Y + 119.0 * Scale,
            "NUMPAD 0 - CHANGE DISGUISE", 109, 205, 255);
    }

    DrawVersusText(C, 20, 20, "HIDE & SEEK   HUNTER " $ G.HunterName);
    DrawVersusText(C, 20, 40, "F3 ROLES");
    if (!bShowVersusScores && G.HideSeekPhase != 'RoundOver')
        return;

    X = C.SizeX * 0.10;
    Y = C.SizeY * 0.18;
    DrawVersusText(C, X, Y, "HIDE & SEEK   " $ string(Count) $ "/8");
    Y += 25.0;
    DrawVersusText(C, X, Y, "NAME");
    DrawVersusText(C, X + 175.0, Y, "CHARACTER");
    DrawVersusText(C, X + 345.0, Y, "ROLE");
    for (I = 0; I < Count; I++)
    {
        Y += 22.0;
        RowPawn = FindPawnForPRI(Rows[I]);
        DrawVersusText(C, X, Y, Rows[I].PlayerName);
        DrawVersusText(C, X + 175.0, Y, Rows[I].SelectedCharacter);
        if (RowPawn != None)
            DrawVersusText(C, X + 345.0, Y,
                RowPawn.GetHideSeekRoleName());
    }
}

simulated function PostRender(Canvas C)
{
    local HPVersusHarry H;
    local HPVersusPRI OwnPRI;
    local HPVersusPRI Rows[8];
    local HPVersusGRI G;
    local HPHideSeekGRI HideSeekGRI;
    local Font SavedFont;
    local Color SavedColor;
    local int SavedStyle;
    local string PhaseText;
    local int Count, I;
    local float X, Y;

    Super.PostRender(C);
    if (bHideHud)
        return;

    H = HPVersusHarry(Owner);
    if (H == None)
        return;

    SavedFont = C.Font;
    SavedColor = C.DrawColor;
    SavedStyle = C.Style;

    OwnPRI = HPVersusPRI(H.PlayerReplicationInfo);
    G = HPVersusGRI(H.GameReplicationInfo);
    HideSeekGRI = HPHideSeekGRI(H.GameReplicationInfo);
    Count = GetSortedPlayers(Rows);
    if (HideSeekGRI != None && OwnPRI != None)
    {
        DrawHideSeekOverlay(C, H, HideSeekGRI, Rows, Count);
        C.Font = SavedFont;
        C.DrawColor = SavedColor;
        C.Style = SavedStyle;
        return;
    }

    DrawVersusCombatPanel(C, H);
    if (G != None && OwnPRI != None)
    {
        C.Font = C.SmallFont;
        if (G.MatchState == 'WaitingForPlayers')
            PhaseText = "WAITING FOR PLAYERS";
        else if (G.MatchState == 'Countdown')
            PhaseText = "MATCH STARTS IN " $ G.RoundTimer;
        else if (G.MatchState == 'MatchOver')
            PhaseText = "WINNER: " $ G.WinnerName
                $ "   NEXT MATCH IN " $ G.RoundTimer;
        else if (H.bVersusDead)
        {
            if (H.VersusRespawnSeconds > 0)
                PhaseText = "RESPAWN IN " $ H.VersusRespawnSeconds;
            else
                PhaseText = "WAITING FOR A FREE SPAWN";
        }
        else
            PhaseText = "FFA   FRAGS " $ OwnPRI.RoundScore $ "/"
                $ G.ScoreLimit $ "   DEATHS " $ int(OwnPRI.Deaths);

        DrawVersusText(C, 20, 20, PhaseText);
        if (Count > 0 && G.MatchState == 'InProgress')
            DrawVersusText(C, 20, 40, "LEADER " $ Rows[0].PlayerName
                $ " (" $ Rows[0].RoundScore $ ")   F3 SCORES");
        else
            DrawVersusText(C, 20, 40, "F3 SCORES");

        // Preserve the accepted scoreboard layout and F3 behaviour.
        if (bShowVersusScores || G.MatchState == 'MatchOver')
        {
            C.Font = C.SmallFont;
            X = C.SizeX * 0.12;
            Y = C.SizeY * 0.18;
            DrawVersusText(C, X, Y, "FREE FOR ALL   " $ Count $ "/8");
            Y += 25;
            DrawVersusText(C, X, Y, "NAME");
            DrawVersusText(C, X + 175, Y, "CHARACTER");
            DrawVersusText(C, X + 325, Y, "FRAGS");
            DrawVersusText(C, X + 405, Y, "DEATHS");
            for (I = 0; I < Count; I++)
            {
                Y += 22;
                DrawVersusText(C, X, Y, Rows[I].PlayerName);
                DrawVersusText(C, X + 175, Y, Rows[I].SelectedCharacter);
                DrawVersusText(C, X + 325, Y, string(Rows[I].RoundScore));
                DrawVersusText(C, X + 405, Y, string(int(Rows[I].Deaths)));
            }
        }
    }

    C.Font = SavedFont;
    C.DrawColor = SavedColor;
    C.Style = SavedStyle;
}
