"""Portable developer entry points. Never writes assets or project settings."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import socket
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VIEWERS = {
    'asset-style-v2': 'blender/environment/studies/dungeons_ground_style_v2/dungeons_ground_style_v2.blend',
    'player-library': 'blender/animation/reviews/player_animation_library_v1/player_animation_library_v1.blend',
    'animation': 'blender/animation/showcase/Animation_Showcase.blend',
    'weapon': 'blender/weapons/showcase/Weapon_Showcase.blend',
    'mobs': 'blender/animation/showcase/Mobs_Animation_Library.blend',
    'soldier': 'blender/characters/soldier/showcase/SOLDIER_Asset_Library.blend',
}
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
    if showcase not in VIEWERS:
        raise ValueError(f'Unknown viewer: {showcase}')
    source = ROOT / VIEWERS[showcase]
    if not source.is_file():
        raise FileNotFoundError(source)
    with source.open('rb') as stream:
        # Blender also supports compressed files (zstd/gzip), without BLENDER
        # at byte zero. Reject LFS pointers, not valid compressed viewers.
        if stream.read(80).startswith(b'version https://git-lfs.github.com/spec/'):
            raise ValueError(f'Not a restored Blender file: {source}. Run git lfs pull first.')
    command = [str(tool), '--factory-startup', '--disable-autoexec', str(source)]
    if showcase in {'asset-style-v2', 'player-library', 'animation', 'weapon', 'mobs', 'soldier'}:
        command += ['--python', str(ROOT / 'scripts/load_showcase_ui.py')]
    if showcase=='asset-style-v2':
        command += ['--python-expr', "print('MD2_SHORT_GRASS_V001 MD2_TALL_GRASS_V001 MD2_GRASS_LIBRARY_V001 MD2_GRASS_WIND_V001 MD2_GRASS_INTERACTION_V001 MD2_FLAT_BLOCKS_V001')"]
    if showcase=='soldier':
        command += ['--python-expr', "print('SOLDIER_FACIAL_UI_V001 SOLDIER_HAIRCARDS_UI_V001_R2')"]
    return command


def viewer_cache() -> Path:
    base = (Path.home() / 'Library/Caches' if platform.system() == 'Darwin'
            else Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))))
    return base / 'GameAssetFactory/viewers' / hashlib.sha256(str(ROOT).encode()).hexdigest()[:12]


def existing_viewer_pid(tool: str, source: Path, *, require_ui: bool = False) -> int | None:
    """Recognize exact viewer paths, including sessions from the earlier launcher."""
    if os.name == 'nt':
        return None
    listing = subprocess.check_output(['ps', '-axo', 'pid=,command='], text=True, timeout=2)
    for line in listing.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) != 2 or not fields[1].startswith(tool + ' '):
            continue
        command = fields[1]
        if require_ui and str(ROOT / 'scripts/load_showcase_ui.py') not in command:
            continue  # Do not reuse a legacy Soldier window with no library panel.
        if require_ui and source.name=='dungeons_ground_style_v2.blend' and 'MD2_SHORT_GRASS_V001' not in command:
            continue  # Preserve stale open studies; use the current review controls.
        if require_ui and source.name=='dungeons_ground_style_v2.blend' and 'MD2_TALL_GRASS_V001' not in command:
            continue  # Keep older short-only windows intact; the new set needs current data/UI.
        if require_ui and source.name=='dungeons_ground_style_v2.blend' and 'MD2_GRASS_LIBRARY_V001' not in command:
            continue  # One shared panel and combined display, rather than older separate sections.
        if require_ui and source.name=='dungeons_ground_style_v2.blend' and 'MD2_GRASS_WIND_V001' not in command:
            continue  # Preserve older loaded studies; this review needs native wind copies and controls.
        if require_ui and source.name=='dungeons_ground_style_v2.blend' and 'MD2_GRASS_INTERACTION_V001' not in command:
            continue  # Preserve loaded Wind-only windows; current review also needs the shared contact field.
        if require_ui and source.name=='dungeons_ground_style_v2.blend' and 'MD2_FLAT_BLOCKS_V001' not in command:
            continue  # Keep older unsaved grass windows; only the current file has the flat-block entries.
        if require_ui and source.name=='SOLDIER_Asset_Library.blend' and 'SOLDIER_FACIAL_UI_V001' not in command:
            continue  # Leave older viewers untouched; their loaded UI lacks the facial system.
        if require_ui and source.name=='SOLDIER_Asset_Library.blend' and 'SOLDIER_HAIRCARDS_UI_V001_R2' not in command:
            continue  # Preserve older open files; the new head selector needs its own bootstrap.
        prefix, found, suffix = command.partition(str(source))
        if found and prefix.endswith(' ') and (not suffix or suffix.startswith(' --')):
            return int(fields[0])
    return None


def check_mcp_port() -> None:
    host = os.environ.get('BLENDER_MCP_HOST', 'localhost')
    port = int(os.environ.get('BLENDER_MCP_PORT', '9876'))
    if host not in {'localhost', '127.0.0.1'} or not 1 <= port <= 65535:
        raise ValueError('MCP requires localhost/127.0.0.1 and a port from 1 to 65535.')
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
            probe.bind(('127.0.0.1', port))
    except OSError as error:
        raise ValueError(f'MCP port {port} is already in use or unavailable. Use the existing bridge '
                         'or set BLENDER_MCP_PORT to a free port and match the MCP client.') from error


def activate_viewer(pid: int) -> None:
    """Bring the existing macOS process forward without UI scripting permissions."""
    if platform.system() != 'Darwin':
        return
    script = ('ObjC.import("AppKit"); '
              f'$.NSRunningApplication.runningApplicationWithProcessIdentifier({pid})'
              '.activateWithOptions($.NSApplicationActivateIgnoringOtherApps);')
    try:
        subprocess.run(['/usr/bin/osascript', '-l', 'JavaScript', '-e', script],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
    except (OSError, subprocess.TimeoutExpired):
        pass  # Activation failure must never lead to a duplicate process.


def launch_blender(command: list[str], viewer: str, *, bridge: bool) -> int:
    cache = viewer_cache()
    cache.mkdir(parents=True, exist_ok=True)
    # Serialize only the short launch operation, never the Blender session.
    with (cache / 'launch.lock').open('a') as lock:
        if os.name != 'nt':
            import fcntl
            fcntl.flock(lock, fcntl.LOCK_EX)
        pid = existing_viewer_pid(command[0], ROOT / VIEWERS[viewer], require_ui=viewer in {'soldier','asset-style-v2'})
        if bridge:
            check_mcp_port()
            addon = Path(os.environ.get('BLENDER_MCP_ADDON', str(Path.home() /
                         'Library/Application Support/Blender/5.2/extensions/user_default/mcp'))).expanduser()
            if platform.system() == 'Darwin' and not (addon / 'mcp_to_blender_server.py').is_file():
                raise FileNotFoundError('Install Blender Lab MCP or set BLENDER_MCP_ADDON to its add-on folder.')
            if pid:
                raise ValueError(f'Viewer already open (PID {pid}). Close it before relaunching with MCP; '
                                 'an existing bridge can be used directly.')
        elif pid:
            activate_viewer(pid)
            print(f'{viewer} is already open (PID {pid}); no additional Blender started.')
            return 0
        log = cache / f'{viewer}.log'
        with log.open('ab', buffering=0) as output:
            process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL,
                                       stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        print(f'Opened {viewer} (PID {process.pid}). Terminal is free. Startup log: {log}')
    return 0


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
        item.add_argument('--blender-bin')
        viewers = item.add_mutually_exclusive_group()
        viewers.add_argument('--viewer', choices=list(VIEWERS), default=None)
        viewers.add_argument('--showcase', choices=['animation', 'weapon'], help='Legacy alias for --viewer')
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
            viewer = args.viewer or args.showcase or 'animation'
            command = blender_command(find_tool('blender', args.blender_bin), viewer)
            if args.mode == 'bridge':
                command += ['--python', str(ROOT / 'scripts/start_blender_mcp.py')]
        if args.dry_run:
            print(json.dumps(command, indent=2)); return 0
        if args.mode in {'blender', 'bridge'}:
            return launch_blender(command, viewer, bridge=args.mode == 'bridge')
        return subprocess.call(command, cwd=ROOT)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(2, f'{error}\n')


if __name__ == '__main__':
    raise SystemExit(main())
