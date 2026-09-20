"""Record supplied artifacts without putting retail/source material in Git."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'Гарри Поттер и Тайная комната'
HANDOFF = ROOT / 'HPVersus_Local_Codex_Handoff_20260920'
OUT = ROOT / 'docs' / 'baseline'
OUT.mkdir(parents=True, exist_ok=True)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def inventory(folder, pattern='*'):
    return {p.relative_to(folder).as_posix(): digest(p.read_bytes())
            for p in sorted(folder.rglob(pattern)) if p.is_file()}

installed = inventory(GAME / 'HGame' / 'Classes', '*.uc')
v18 = inventory(ROOT / 'v18' / 'v18' / 'HGame' / 'Classes', '*.uc')
result = {'installed_sources': installed, 'v18_sources': v18,
          'installed_equals_v18': installed == v18, 'artifacts': {}, 'versions': {}}
for p in [GAME / 'System' / 'HGame.u', ROOT / 'v18' / 'v18' / 'HGame.u',
          GAME / 'System' / 'UCC.exe', GAME / 'System' / 'Engine.u']:
    result['artifacts'][p.relative_to(ROOT).as_posix()] = digest(p.read_bytes())
for p in sorted(HANDOFF.rglob('*.zip')):
    result['artifacts'][p.relative_to(ROOT).as_posix()] = digest(p.read_bytes())
    with zipfile.ZipFile(p) as z:
        source = {}
        for info in z.infolist():
            name = info.filename.replace('\\', '/')
            if '/Classes/' in name and name.endswith('.uc'):
                source[name.split('/Classes/', 1)[1]] = digest(z.read(info))
        if source:
            result['versions'][p.stem] = source
(OUT / 'manifest.json').write_text(json.dumps(result, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
print('Installed and v18 classes identical:', installed == v18, 'count:', len(installed))
print(json.dumps(result['artifacts'], ensure_ascii=False, indent=2))
