#!/usr/bin/env python3
"""Rebuild the private pack audit index into an external cache, never the repo."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import zipfile

PACK_SHA256 = "9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d"
INDEX_SHA256 = "08f3a2261d8d2abb4fd1e3c9f7dba54b77d31971b16e0ac817acd960db43f26a"
REPO = Path(__file__).resolve().parents[2]


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def cache_output():
    base = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    return base / "GameAssetFactory" / "actions_stuff" / PACK_SHA256 / "source_index.json"


def generate(pack, output):
    output = output.expanduser().resolve()
    if output == REPO or REPO in output.parents:
        raise ValueError("Output must be outside the repository; canonical audit data is preserved.")
    actual = sha256(pack)
    if actual != PACK_SHA256:
        raise ValueError(f"Pack checksum mismatch: expected {PACK_SHA256}, got {actual}.")
    index = {}
    with zipfile.ZipFile(pack) as archive:
        # ZIP order and indent=2 reproduce the original audit bytes exactly.
        for path in archive.namelist():
            if not path.endswith(".json") or path.split("/")[0] not in {
                "animations", "animation_controllers", "render_controllers", "models"
            }:
                continue
            document = json.loads(archive.read(path))
            records = []
            for category in ["animations", "animation_controllers", "render_controllers"]:
                records.extend(document.get(category, {}).items())
            records.extend((data["description"]["identifier"], data)
                           for data in document.get("minecraft:geometry", []))
            for identifier, data in records:
                if identifier in index:
                    raise ValueError(f"Duplicate source identifier: {identifier}")
                index[identifier] = {"path": path, "data": data}
    content = json.dumps(index, indent=2).encode("utf-8")
    digest = hashlib.sha256(content).hexdigest()
    if digest != INDEX_SHA256:
        raise ValueError(f"Generated index checksum mismatch: {digest}; no output written.")
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix=".source-index-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(content)
        os.replace(temporary, output)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()
    print(f"Generated {len(index):,} entries / {len(content):,} bytes: {output}")
    print(f"Pack SHA256: {actual}\nIndex SHA256: {digest}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", required=True, type=Path,
                        help="Local matching Actions Stuff1.12 resources.mcpack; never downloaded")
    parser.add_argument("--output", type=Path, default=None,
                        help="External output; default is the checksum-specific user cache")
    args = parser.parse_args(argv)
    try:
        generate(args.pack.expanduser(), args.output if args.output is not None else cache_output())
    except (OSError, ValueError, zipfile.BadZipFile, KeyError) as error:
        print(f"source-index generator: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
