"""Portable developer entry points. Never writes assets or project settings."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SCENES = {
    'snappy': 'res://scenes/dev/SnappyLocomotionFastJumpTest.tscn',
    'expressive': 'res://scenes/dev/ExpressiveLocomotionTest.tscn',
    'grassland': 'res://scenes/Grassland.tscn',
    'lookdev': 'res://scenes/GrasslandLookDev.tscn',
    'meadow': 'res://scenes/ForestMeadowV3.tscn',
}


def find_tool(name: str, explicit: str | None = None) -> Path:
    override = explicit or os.environ.get(name.upper() + '_BIN')
    if override:
        path = Path(override).expanduser()
        if not path.is_file():
            raise FileNotFoundError(f'{name}: executable not found at {path}')
        return path.resolve()
    for command in ([name, 'godot4'] if name == 'godot' else [name]):
        found = shutil.which(command)
        if found:
            return Path(found).resolve()
    candidates = []
    if platform.system() == 'Darwin':
        app = 'Blender' if name == 'blender' else 'Godot'
        for folder in [Path('/Applications'), Path.home() / 'Applications']:
            candidates.append(folder / f'{app}.app/Contents/MacOS/{app}')
    elif platform.system() == 'Windows':
        if name == 'blender':
            folder = Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Blender Foundation'
            candidates.extend(sorted(folder.glob('Blender */blender.exe'), reverse=True))
        else:
            folder = Path.home() / 'Downloads'
            candidates.extend(sorted(folder.glob('Godot_v4.7.2*/Godot_v4.7.2*win64.exe')))
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(f'Set {name.upper()}_BIN to the executable, or put {name} on PATH.')


def godot_command(tool: Path, scene: str | None, editor: bool, headless: bool) -> list[str]:
    command = [str(tool), '--path', str(ROOT / 'game_mobile_3d'), '--rendering-method', 'mobile']
    if platform.system() == 'Windows' and not headless:
        command += ['--rendering-driver', 'd3d12']
    if headless:
        command.append('--headless')
    if editor:
        command.append('--editor')
    if scene:
        resource = SCENES.get(scene, scene)
        if not resource.startswith('res://') or '..' in Path(resource[6:]).parts or '\\' in resource:
            raise ValueError('Scene must be a known alias or repository res:// path.')
        if not (ROOT / 'game_mobile_3d' / resource[6:]).is_file():
            raise FileNotFoundError(resource)
        command.append(resource)
    return command


def blender_command(tool: Path, showcase: str) -> list[str]:
    relative = ('blender/animation/showcase/Animation_Showcase.blend' if showcase == 'animation'
                else 'blender/weapons/showcase/Weapon_Showcase.blend')
    return [str(tool), '--factory-startup', '--disable-autoexec', str(ROOT / relative),
            '--python', str(ROOT / 'scripts/load_showcase_ui.py')]


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='mode', required=True)
    sub.add_parser('doctor', help='Read-only tool and project discovery')
    game = sub.add_parser('godot')
    game.add_argument('--godot-bin'); game.add_argument('--scene', choices=None)
    game.add_argument('--editor', action='store_true'); game.add_argument('--headless', action='store_true')
    game.add_argument('--dry-run', action='store_true')
    for mode in ['blender', 'bridge']:
        item = sub.add_parser(mode)
        item.add_argument('--blender-bin'); item.add_argument('--showcase', choices=['animation', 'weapon'], default='animation')
        item.add_argument('--dry-run', action='store_true')
    args = parser.parse_args(argv)
    try:
        if args.mode == 'doctor':
            result = {'python': sys.version.split()[0], 'platform': platform.system(), 'root': str(ROOT)}
            for name in ['blender', 'godot']:
                try: result[name] = str(find_tool(name))
                except FileNotFoundError as error: result[name] = str(error)
            print(json.dumps(result, indent=2)); return 0
        if args.mode == 'godot':
            command = godot_command(find_tool('godot', args.godot_bin), args.scene, args.editor, args.headless)
        else:
            command = blender_command(find_tool('blender', args.blender_bin), args.showcase)
            if args.mode == 'bridge':
                command += ['--python', str(ROOT / 'scripts/start_blender_mcp.py')]
        if args.dry_run:
            print(json.dumps(command, indent=2)); return 0
        return subprocess.call(command, cwd=ROOT)
    except (FileNotFoundError, ValueError) as error:
        parser.exit(2, f'{error}\n')


if __name__ == '__main__':
    raise SystemExit(main())
