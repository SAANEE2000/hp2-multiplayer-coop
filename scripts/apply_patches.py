"""Apply byte-checked, idempotent recipes to an explicitly marked local copy."""
import argparse
import hashlib
import json
from pathlib import Path

def sha(data):
    return hashlib.sha256(data).hexdigest()

def apply_recipe(root, recipe_path):
    recipe = json.loads(recipe_path.read_text(encoding='utf-8-sig'))
    pending = []
    for entry in recipe['files']:
        target = (root / entry['path']).resolve()
        if not target.is_relative_to(root):
            raise ValueError('Patch target escapes development tree')
        original = target.read_bytes()
        if sha(original) == entry['result_sha256']:
            continue
        if sha(original) != entry['source_sha256']:
            raise ValueError(f"Source hash mismatch: {entry['path']}")
        modified = original
        for edit in entry['replacements']:
            before, after = edit['old'].encode('latin-1'), edit['new'].encode('latin-1')
            if modified.count(before) != 1:
                raise ValueError(f"Non-unique patch anchor: {entry['path']}")
            modified = modified.replace(before, after, 1)
        if sha(modified) != entry['result_sha256']:
            raise ValueError(f"Output hash mismatch: {entry['path']}")
        pending.append((target, original, modified))
    for target, original, modified in pending:
        backup = root / '.patch-backups' / recipe['name'] / target.relative_to(root)
        backup.parent.mkdir(parents=True, exist_ok=True)
        if not backup.exists():
            backup.write_bytes(original)
        temporary = target.with_suffix(target.suffix + '.patch-tmp')
        temporary.write_bytes(modified)
        temporary.replace(target)
    print(f"{recipe['name']}: {len(pending)} files updated; all hashes verified")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--work-root', required=True, type=Path)
    parser.add_argument('recipes', nargs='+', type=Path)
    args = parser.parse_args()
    root = args.work_root.resolve()
    if not (root / '.hp2-development-copy.json').is_file():
        raise ValueError('Refusing to patch a tree without the development-copy marker')
    for recipe in args.recipes:
        apply_recipe(root, recipe)
