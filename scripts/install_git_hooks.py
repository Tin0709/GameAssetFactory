#!/usr/bin/env python3
"""Opt in to the local pre-commit guard without changing Git configuration."""
import argparse
from pathlib import Path
import subprocess
import sys

MARKER = "# GameAssetFactory large-file guard v1"


def install(repo, dry_run=False):
    config = subprocess.run(["git", "config", "--get", "core.hooksPath"], cwd=repo,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if config.returncode == 0:
        raise RuntimeError("core.hooksPath is configured; integrate the guard manually "
                           "with that hook owner. No hooks or configuration changed.")
    if config.returncode != 1:
        raise RuntimeError(config.stderr.decode(errors="replace").strip())
    result = subprocess.run(["git", "rev-parse", "--git-path", "hooks"], cwd=repo,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    hook_dir = Path(result.stdout.strip())
    if not hook_dir.is_absolute():
        hook_dir = repo / hook_dir
    destination = hook_dir / "pre-commit"
    if destination.is_symlink():
        raise RuntimeError("Existing pre-commit is a symlink; leave its owner in control.")
    if destination.exists() and MARKER not in destination.read_text(errors="replace").splitlines():
        raise RuntimeError("Existing unrelated pre-commit hook preserved; integrate manually.")
    source = Path(__file__).parent / "git_hooks" / "pre-commit"
    text = source.read_bytes()
    if dry_run:
        print(f"Would install {destination}; existing pre-push and Git config stay unchanged.")
        return
    hook_dir.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(text)
    destination.chmod(destination.stat().st_mode | 0o111)
    print(f"Installed {destination}; existing pre-push and Git config stay unchanged.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    try:
        install(args.repo.resolve(), args.dry_run)
    except (OSError, RuntimeError) as error:
        print(f"hook installer: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
