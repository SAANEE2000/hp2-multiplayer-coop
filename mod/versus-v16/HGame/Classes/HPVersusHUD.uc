// Versus-only overlay on the original HP2 HUD. Match facts come from the
// server's replicated pawn, PRI and GRI; this class never awards points.
class HPVersusHUD extends HPHud;

var bool bShowVersusScores;

simulated function DrawVersusText(Canvas C, float X, float Y, string Message)
{
    C.DrawColor.R = 0;
    C.DrawColor.G = 0;
    C.DrawColor.B = 0;
    C.SetPos(X + 1, Y + 1);
    C.DrawText(Message, False);
    C.DrawColor.R = 245;
    C.DrawColor.G = 238;
    C.DrawColor.B = 210;
    C.SetPos(X, Y);
    C.DrawText(Message, False);
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

simulated function PostRender(Canvas C)
{
    local HPVersusHarry H;
    local HPVersusPRI OwnPRI;
    local HPVersusPRI Rows[8];
    local HPVersusGRI G;
    local Font SavedFont;
    local Color SavedColor;
    local string PhaseText;
    local string CombatText;
    local int Count, I;
    local float X, Y, SpeedLeft, LockLeft, DisarmLeft;

    Super.PostRender(C);
    if (bHideHud)
        return;

    H = HPVersusHarry(Owner);
    if (H == None)
        return;
    OwnPRI = HPVersusPRI(H.PlayerReplicationInfo);
    G = HPVersusGRI(H.GameReplicationInfo);
    if (G == None || OwnPRI == None)
        return;

    SavedFont = C.Font;
    SavedColor = C.DrawColor;
    C.Font = C.MedFont;
    X = 20;
    Y = 22;
    DrawVersusText(C, X, Y, "HP " $ H.Health $ "/100   Frags " $ OwnPRI.RoundScore
        $ "/" $ G.ScoreLimit $ "   Deaths " $ int(OwnPRI.Deaths));

    CombatText = "[" $ string(int(H.SelectedVersusSpell) + 1) $ "] "
        $ H.GetVersusSpellName(H.SelectedVersusSpell);
    LockLeft = H.VersusSpellLockEndTime - Level.TimeSeconds;
    DisarmLeft = H.VersusDisarmEndTime - Level.TimeSeconds;
    if (DisarmLeft > 0.0)
        CombatText = CombatText $ "   DISARMED "
            $ string(int(DisarmLeft + 0.99)) $ "s";
    else if (LockLeft > 0.0)
        CombatText = CombatText $ "   MUTED " $ string(int(LockLeft + 0.99)) $ "s";
    else if (H.VersusCooldownEndTime > Level.TimeSeconds)
        CombatText = CombatText $ "   COOLDOWN";
    else
        CombatText = CombatText $ "   READY";
    SpeedLeft = H.VersusSpeedBoostEndTime - Level.TimeSeconds;
    if (H.VersusSpeedMultiplier > 1.01 && SpeedLeft > 0.0)
        CombatText = CombatText $ "   SPEED x" $ string(H.VersusSpeedMultiplier)
            $ " " $ string(int(SpeedLeft + 0.99)) $ "s";
    DrawVersusText(C, X, Y + 22, CombatText);

    if (G.MatchState == 'WaitingForPlayers')
        PhaseText = "Waiting for players";
    else if (G.MatchState == 'Countdown')
        PhaseText = "Match starts in " $ G.RoundTimer;
    else if (G.MatchState == 'MatchOver')
        PhaseText = "Winner: " $ G.WinnerName $ "   Next match in " $ G.RoundTimer;
    else
        PhaseText = "Free-for-all in progress";

    if (H.bVersusDead && G.MatchState != 'MatchOver')
    {
        if (H.VersusRespawnSeconds > 0)
            PhaseText = "Respawn in " $ H.VersusRespawnSeconds;
        else
            PhaseText = "Waiting for a free spawn";
    }
    DrawVersusText(C, X, Y + 44, PhaseText);

    Count = GetSortedPlayers(Rows);
    if (Count > 0 && G.MatchState == 'InProgress')
        DrawVersusText(C, X, Y + 66, "Leader: " $ Rows[0].PlayerName
            $ " (" $ Rows[0].RoundScore $ ")   F3: scores");
    else
        DrawVersusText(C, X, Y + 66, "F3: scores");

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
    C.Font = SavedFont;
    C.DrawColor = SavedColor;
}
