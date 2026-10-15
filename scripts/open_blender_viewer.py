"""Open an existing Blender viewer from any working directory, then exit."""
from __future__ import annotations

import argparse

import dev

VIEWERS = {
    'asset': 'asset-style-v2',
    'player': 'player-library',
    'animation': 'animation',
    'weapon': 'weapon',
    'mobs': 'mobs',
}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('viewer', choices=VIEWERS)
    parser.add_argument('--blender-bin', help='Override BLENDER_BIN / automatic discovery')
    parser.add_argument('--dry-run', action='store_true', help='Print arguments without opening Blender')
    args = parser.parse_args(argv)
    command = ['blender', '--viewer', VIEWERS[args.viewer]]
    if args.blender_bin:
        command += ['--blender-bin', args.blender_bin]
    if args.dry_run:
        command += ['--dry-run']
    return dev.main(command)


if __name__ == '__main__':
    raise SystemExit(main())
