"""Validate complete byte/hash chains before patching a marked development copy."""
import argparse
import hashlib
import json
from pathlib import Path, PureWindowsPath
import re
import stat
import tempfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def checked_hash(value):
    if not isinstance(value, str) or not re.fullmatch(r"[a-fA-F0-9]{64}", value):
        raise ValueError("Invalid SHA256 in patch recipe")
    return value.lower()


def safe_path(root, relative, label="Patch target"):
    """Reject escapes and aliases before reading or creating a target/backup."""
    if not isinstance(relative, str) or not relative:
        raise ValueError(f"{label} escapes development tree")
    relative = relative.replace("\\", "/")
    parts = Path(relative).parts
    if (Path(relative).is_absolute() or PureWindowsPath(relative).drive
            or ".." in parts or not parts or ":" in relative):
        raise ValueError(f"{label} escapes development tree")
    candidate = root / relative
    resolved = candidate.resolve()
    if resolved == root or not resolved.is_relative_to(root):
        raise ValueError(f"{label} escapes development tree")
    current = root
    for part in parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(f"{label} uses a symlink/reparse point")
        if current.exists():
            attrs = getattr(current.lstat(), "st_file_attributes", 0)
            if attrs & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400):
                raise ValueError(f"{label} uses a symlink/reparse point")
            if current != candidate and not current.is_dir():
                raise ValueError(f"{label} parent is not a directory")
    return resolved


def order_chain(edges, relative):
    outgoing, incoming = {}, {}
    for edge in edges:
        source, result = edge["source"], edge["result"]
        if source in outgoing:
            raise ValueError(f"Forked patch chain: {relative}")
        if result in incoming:
            raise ValueError(f"Ambiguous predecessor in patch chain: {relative}")
        outgoing[source], incoming[result] = edge, edge
    roots = set(outgoing) - set(incoming)
    if not roots:
        raise ValueError(f"Cyclic patch chain: {relative}")
    if len(roots) != 1:
        raise ValueError(f"Disconnected patch chain (missing predecessor): {relative}")
    cursor = roots.pop()
    ordered, visited = [], set()
    while cursor in outgoing:
        if cursor in visited:
            raise ValueError(f"Cyclic patch chain: {relative}")
        visited.add(cursor)
        edge = outgoing[cursor]
        ordered.append(edge)
        cursor = edge["result"]
    if len(ordered) != len(edges):
        raise ValueError(f"Disconnected patch chain (missing predecessor): {relative}")
    return ordered


def apply_recipes(root, recipe_paths):
    root = Path(root).resolve()
    marker = safe_path(root, ".hp2-development-copy.json", "Development marker")
    if not marker.is_file():
        raise ValueError("Refusing to patch a tree without the development-copy marker")

    targets, names = {}, set()
    for recipe_path in recipe_paths:
        recipe = json.loads(Path(recipe_path).read_text(encoding="utf-8-sig"))
        name = recipe["name"]
        if (not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", name)
                or name.casefold() in names):
            raise ValueError("Invalid or duplicate recipe name")
        names.add(name.casefold())
        if recipe.get("schema_version", 1) != 1 or not recipe["files"]:
            raise ValueError("Unsupported or empty patch recipe")
        for entry in recipe["files"]:
            target = safe_path(root, entry["path"])
            relative = target.relative_to(root)
            if relative.parts[0].casefold() in {".patch-backups", ".hp2-development-copy.json"}:
                raise ValueError("Patch target overlaps patch metadata")
            edits = []
            for edit in entry["replacements"]:
                before, after = edit["old"].encode("latin-1"), edit["new"].encode("latin-1")
                if not before:
                    raise ValueError(f"Non-unique patch anchor: {relative}")
                for field, data in (("old_sha256", before), ("new_sha256", after)):
                    if field in edit and sha(data) != checked_hash(edit[field]):
                        raise ValueError(f"Replacement hash mismatch: {relative}")
                edits.append((before, after))
            backup = safe_path(root, str(Path(".patch-backups") / name / relative), "Patch backup")
            edge = dict(name=name, source=checked_hash(entry["source_sha256"]),
                        result=checked_hash(entry["result_sha256"]), edits=edits, backup=backup)
            targets.setdefault(target, []).append(edge)

    # Plan every target and every intermediate backup in memory. No directory,
    # backup or temporary file is created until the complete batch validates.
    plans, backups, originals = [], [], {}
    for target, edges in targets.items():
        relative = target.relative_to(root)
        chain = order_chain(edges, relative)
        original = target.read_bytes()
        originals[target] = original
        nodes = [chain[0]["source"]] + [edge["result"] for edge in chain]
        current = sha(original)
        if current not in nodes:
            raise ValueError(f"Source hash mismatch: {relative}")
        for edge in chain:
            if edge["backup"].exists():
                if not edge["backup"].is_file() or sha(edge["backup"].read_bytes()) != edge["source"]:
                    raise ValueError(f"Backup hash mismatch: {relative} ({edge['name']})")
        modified = original
        for edge in chain[nodes.index(current):]:
            before_recipe = modified
            for before, after in edge["edits"]:
                if modified.count(before) != 1:
                    raise ValueError(f"Non-unique patch anchor: {relative}")
                modified = modified.replace(before, after, 1)
            if sha(modified) != edge["result"]:
                raise ValueError(f"Output hash mismatch: {relative} ({edge['name']})")
            if not edge["backup"].exists():
                backups.append((edge["backup"], before_recipe))
        if modified != original:
            plans.append((target, modified))

    # Detect an input changed while the complete batch was being validated.
    for target, original in originals.items():
        if target.read_bytes() != original:
            raise ValueError(f"Source changed during validation: {target.relative_to(root)}")
    for backup, data in backups:
        backup.parent.mkdir(parents=True, exist_ok=True)
        with backup.open("xb") as stream:
            stream.write(data)
    for target, modified in plans:
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=target.parent, prefix=target.name + ".",
                                             suffix=".patch-tmp", delete=False) as stream:
                temporary = Path(stream.name)
                stream.write(modified)
            temporary.replace(target)
        finally:
            if temporary is not None and temporary.exists():
                temporary.unlink()
    print(f"Patch batch: {len(plans)} files updated; {len(targets)} complete hash chains verified")


def apply_recipe(root, recipe_path):
    """Compatibility entry point for a standalone/synthetic one-recipe batch."""
    apply_recipes(root, [recipe_path])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--work-root", required=True, type=Path)
    parser.add_argument("recipes", nargs="+", type=Path)
    args = parser.parse_args()
    apply_recipes(args.work_root, args.recipes)
