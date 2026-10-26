#!/usr/bin/env python3
"""Read staged Git objects; never stage, migrate, or edit repository content."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

MIB = 1024 * 1024
LFS_POINTER = re.compile(
    rb"version https://git-lfs.github.com/spec/v1\n"
    rb"oid sha256:[0-9a-f]{64}\nsize (?:0|[1-9][0-9]*)\n"
)


def git(repo, *args, data=None):
    result = subprocess.run(["git", *args], cwd=repo, input=data,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    if result.returncode:
        raise RuntimeError(result.stderr.decode(errors="replace").strip())
    return result.stdout


def inspect_staged(repo):
    # Disabling rename detection makes every rename destination an added path.
    # NUL delimiters retain spaces, tabs and newlines without shell parsing.
    changed = set(git(repo, "diff", "--cached", "--name-only", "-z",
                      "--diff-filter=ACMRT", "--no-renames").split(b"\0")) - {b""}
    if not changed:
        return []
    entries = []
    for record in git(repo, "ls-files", "--stage", "-z").split(b"\0"):
        if not record:
            continue
        metadata, path = record.split(b"\t", 1)
        mode, oid, stage = metadata.split()
        # Git does not apply clean filters to symlink target blobs or gitlinks.
        if path in changed and stage == b"0" and mode not in {b"120000", b"160000"}:
            entries.append((path, oid))
    if not entries:
        return []
    attributes = git(repo, "check-attr", "--cached", "-z", "filter", "--stdin",
                     data=b"\0".join(path for path, _ in entries) + b"\0").split(b"\0")
    filters = {attributes[i]: attributes[i + 2] for i in range(0, len(attributes) - 1, 3)}
    metadata = git(repo, "cat-file", "--batch-check=%(objectname) %(objecttype) %(objectsize)",
                   data=b"\n".join(oid for _, oid in entries) + b"\n").splitlines()
    issues = []
    for (path, oid), row in zip(entries, metadata):
        _, kind, size = row.split()
        if kind != b"blob":
            raise RuntimeError("Expected a staged blob for " + repr(os.fsdecode(path)))
        size = int(size)
        content = git(repo, "cat-file", "blob", oid.decode()) if size <= 1024 else b""
        pointer = LFS_POINTER.fullmatch(content) is not None
        lfs = filters.get(path) == b"lfs"
        name = repr(os.fsdecode(path))
        if pointer and not lfs:
            issues.append(("BLOCK", f"{name}: LFS pointer requires staged filter=lfs attribute."))
        elif lfs and size and not pointer:
            # Git LFS stores an empty file as an ordinary zero-byte blob.
            issues.append(("BLOCK", f"{name}: invalid LFS pointer in staged filter=lfs path; "
                           "run normal git add with Git LFS available before committing."))
        elif pointer or (lfs and size == 0):
            continue
        elif size > 25 * MIB:
            level = "BLOCK" if size > 100 * MIB else "REVIEW" if size > 50 * MIB else "WARN"
            suffix = " Commit blocked." if level == "BLOCK" else " Commit allowed."
            issues.append((level, f"{name}: ordinary staged Git blob {size:,} bytes "
                           f"({size / MIB:.2f} MiB)." + suffix))
    return issues


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    try:
        issues = inspect_staged(args.repo)
    except (OSError, RuntimeError, ValueError) as error:
        print(f"large-file guard: {error}", file=sys.stderr)
        return 2
    for level, message in issues:
        print(f"large-file guard {level}: {message}", file=sys.stderr)
    if issues:
        print("Review generated artifacts or choose path-specific LFS deliberately; "
              "this check does not change tracking.", file=sys.stderr)
    return 1 if any(level == "BLOCK" for level, _ in issues) else 0


if __name__ == "__main__":
    sys.exit(main())
