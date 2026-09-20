// Runtime-only marker; ordinary PlayerStart is static/no-delete in M212.
// Explicitly selected by HPCoopGame, never by the single-player start search.
class HPCoopStart extends PlayerStart;

defaultproperties
{
    bStatic=False
    bNoDelete=False
    bEnabled=False
    bSinglePlayerStart=False
    bCoopStart=False
    bCollideWhenPlacing=False
    RemoteRole=ROLE_None
}
