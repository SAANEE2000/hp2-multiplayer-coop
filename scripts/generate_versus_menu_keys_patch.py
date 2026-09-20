"""Generate the narrow HPConsole patch for Versus launched from the main menu."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / ".local/game/HGame/Classes/Internal/HPConsole.uc"
OUTPUT = ROOT / "patches/versus-menu-spell-keys.json"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def replacement(old, new):
    before = old.encode("latin-1")
    after = new.encode("latin-1")
    return {
        "old": old,
        "new": new,
        "old_sha256": sha(before),
        "new_sha256": sha(after),
    }


source = SOURCE.read_bytes()
old_function = "function bool ApplyVersusMovementKey(EInputKey Key, EInputAction Action)\r\n"
new_function = (
    "// Menu-launched Versus retains the player's ordinary User.ini. Intercept the\r\n"
    "// number keys only while a local Versus pawn owns gameplay input.\r\n"
    "function bool ApplyVersusSpellKey(EInputKey Key, EInputAction Action)\r\n"
    "{\r\n"
    "    local HPVersusHarry H;\r\n"
    "    if (Action != IST_Press) return False;\r\n"
    "    H = GetLocalVersusPawn();\r\n"
    "    if (H == None) return False;\r\n"
    "    switch (Key)\r\n"
    "    {\r\n"
    "        case IK_1: H.VersusSpell1(); return True;\r\n"
    "        case IK_2: H.VersusSpell2(); return True;\r\n"
    "        case IK_3: H.VersusSpell3(); return True;\r\n"
    "        case IK_4: H.VersusSpell4(); return True;\r\n"
    "        case IK_5: H.VersusSpell5(); return True;\r\n"
    "        case IK_6: H.VersusSpell6(); return True;\r\n"
    "    }\r\n"
    "    return False;\r\n"
    "}\r\n"
    "\r\n"
    + old_function
)
old_call = "\tApplyVersusMovementKey(Key, Action);\r\n\tk = Key;"
new_call = "\tApplyVersusMovementKey(Key, Action);\r\n\tif (ApplyVersusSpellKey(Key, Action)) return True;\r\n\tk = Key;"
edits = [(old_function, new_function), (old_call, new_call)]
result = source
for old, new in edits:
    before = old.encode("latin-1")
    if result.count(before) != 1:
        raise ValueError(f"HPConsole patch anchor count is {result.count(before)}")
    result = result.replace(before, new.encode("latin-1"), 1)
recipe = {
    "schema_version": 1,
    "name": "versus-menu-spell-keys",
    "description": "Make Versus number-key spell selection work from ordinary game settings without changing User.ini or single-player controls.",
    "files": [{
        "path": "HGame/Classes/Internal/HPConsole.uc",
        "source_sha256": sha(source),
        "result_sha256": sha(result),
        "replacements": [replacement(old, new) for old, new in edits],
    }],
}
OUTPUT.write_text(json.dumps(recipe, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
print(OUTPUT)
