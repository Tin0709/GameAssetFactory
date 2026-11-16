"""Build and profile a device review export without editing the main Godot checkout."""

from __future__ import annotations

import argparse
from datetime import datetime
import json
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
from statistics import median
import subprocess
import sys
import tempfile

from dev import ROOT, find_tool


GODOT_VERSION = "4.7.2.stable.official.ed1daf0bf"
PROJECT = ROOT / "game_mobile_3d"
BUILD_ROOT = PROJECT / "builds" / "device_review"
PRESET = "GameAssetFactory Device Review"
PRODUCT = "GameAssetFactoryReview"


def run(*args, capture=False):
    command = [str(part) for part in args]
    if capture:
        return subprocess.check_output(command, text=True, encoding="utf-8")
    subprocess.run(command, check=True)


def on_mac() -> None:
    if platform.system() != "Darwin":
        raise ValueError("Run this command on the Mac with full Xcode installed.")


def verify_godot(explicit: str | None) -> Path:
    godot = find_tool("godot", explicit)
    if platform.system() == "Windows":
        console = godot.with_name(godot.stem + "_console.exe")
        if console.is_file():
            godot = console
    version = run(godot, "--version", capture=True).strip()
    if version != GODOT_VERSION:
        raise ValueError(f"Expected Godot {GODOT_VERSION}, got {version}. Set GODOT_BIN to the matching editor.")
    return godot


def verify_xcode() -> None:
    on_mac()
    run("xcodebuild", "-version")
    run("xcrun", "--sdk", "iphoneos", "--show-sdk-path")


def stage(target: Path) -> int:
    tracked = run("git", "-C", ROOT, "ls-files", "-z", "--", PROJECT.name, capture=True)
    lfs_pointer = b"version https://git-lfs.github.com/spec/v1"
    count = 0
    for name in filter(None, tracked.split("\0")):
        relative = PurePosixPath(name).relative_to(PROJECT.name)
        if relative.parts[0] in {"builds", ".godot", "tests"}:
            continue
        if any("private" in part.casefold() for part in relative.parts):
            continue
        source = PROJECT.joinpath(*relative.parts)
        if source.is_symlink() or not source.resolve().is_relative_to(PROJECT):
            raise ValueError(f"Unexpected external path in project: {relative}")
        if source.stat().st_size < 1024 and source.read_bytes().startswith(lfs_pointer):
            raise ValueError(f"Missing LFS object for {relative}. Run git lfs pull.")
        copy = target.joinpath(*relative.parts)
        copy.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, copy)
        count += 1
    settings = target / "project.godot"
    text = settings.read_text(encoding="utf-8")
    text = text.replace('[display]\n', '[display]\n\nwindow/handheld/orientation=0\n')
    text = text.replace('[rendering]\n', '[rendering]\n\nrenderer/rendering_method.mobile="mobile"\n'
                        'rendering_device/driver.ios="metal"\n'
                        'textures/vram_compression/import_etc2_astc=true\n')
    commit = run("git", "-C", ROOT, "rev-parse", "--short", "HEAD", capture=True).strip()
    dirty = bool(run("git", "-C", ROOT, "status", "--porcelain", "--", PROJECT.name, capture=True).strip())
    text += f'\n[gaf_device_review]\n\nsource_commit="{commit}"\nsource_dirty={str(dirty).lower()}\n'
    settings.write_text(text, encoding="utf-8")
    return count


def preset(target: Path, team: str = "", bundle: str = "") -> None:
    if team and not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("Use the ten-character Apple Team ID from Xcode.")
    if bundle and not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle):
        raise ValueError("Use a reverse-DNS bundle identifier assigned to your team.")
    platform_name = "iOS" if team else "Windows Desktop"
    contents = f'''[preset.0]
name="{PRESET}"
platform="{platform_name}"
runnable=true
advanced_options=false
dedicated_server=false
custom_features="gaf_device_review"
export_filter="all_resources"
include_filter="assets/maps/world_map/*.json,assets/environment/litematic_m2_v1/*.json"
exclude_filter="*.private.*,private_*,tests/*,tools/*,scenes/dev/*,scripts/world_map_source_reference.gd"
export_path=""
script_export_mode=2

[preset.0.options]
'''
    if team:
        contents += f'''application/app_store_team_id="{team}"
application/bundle_identifier="{bundle}"
application/export_project_only=true
architectures/arm64=true
'''
    else:
        contents += 'binary_format/architecture="x86_64"\n'
    (target / "export_presets.cfg").write_text(contents, encoding="utf-8")


def export(args: argparse.Namespace) -> None:
    ios = args.command == "build"
    if ios:
        verify_xcode()
        template = Path.home() / "Library/Application Support/Godot/export_templates/4.7.2.stable/ios.zip"
        if not template.is_file():
            raise ValueError(f"Install the matching Godot export templates from Editor → Manage Export Templates. Missing {template}")
    godot = verify_godot(args.godot)
    output = BUILD_ROOT / datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    output.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix="gaf-device-review-") as temporary:
        staged = Path(temporary)
        count = stage(staged)
        preset(staged, args.team_id, args.bundle_id) if ios else preset(staged)
        print(f"Staged {count} tracked project files. Output: {output}", flush=True)
        base = (godot, "--headless", "--path", staged)
        run(*base, "--import", "--log-file", output / "import.log")
        if not ios:
            pack = output / f"{PRODUCT}.pck"
            run(*base, "--export-pack", PRESET, pack, "--log-file", output / "export.log")
            if not pack.is_file() or not pack.stat().st_size:
                raise ValueError("Godot did not produce the review pack.")
            # Run with nothing in res:// except the exported pack.
            with tempfile.TemporaryDirectory(prefix="gaf-pack-launch-") as empty:
                log = run(godot, "--headless", "--path", empty, "--main-pack", pack, "--audio-driver",
                          "Dummy", "--rendering-method", "gl_compatibility", "--quit-after", "60",
                          "--log-file", output / "pack_smoke.log", capture=True)
                errors = (output / "pack_smoke.log").read_text(encoding="utf-8", errors="replace")
                if "WORLD_MAP_READY" not in log or "GAF_DEVICE_REVIEW " not in log or "ERROR:" in errors:
                    raise ValueError(f"Pack smoke failed. See {output / 'pack_smoke.log'}.")
                print(log.strip())
            return
        config = "Release" if args.release_template else "Debug"
        flag = "--export-release" if args.release_template else "--export-debug"
        run(*base, flag, PRESET, output / f"{PRODUCT}.ipa", "--log-file", output / "export.log")
    project = output / f"{PRODUCT}.xcodeproj"
    if not project.is_dir():
        raise ValueError(f"Godot did not produce {project}. See {output / 'export.log'}.")
    print(f"Xcode project: {project}")
    if not args.device:
        return
    config_dir = output / "Device"
    changes = ["-allowProvisioningUpdates"] if args.allow_provisioning_updates else []
    run("xcodebuild", "-project", project, "-scheme", PRODUCT, "-configuration", config,
        "-destination", f"platform=iOS,id={args.device}", "-derivedDataPath", output / "DerivedData",
        f"CONFIGURATION_BUILD_DIR={config_dir}", f"DEVELOPMENT_TEAM={args.team_id}",
        "CODE_SIGN_STYLE=Automatic", *changes, "build")
    app = config_dir / f"{PRODUCT}.app"
    if not app.is_dir():
        raise ValueError(f"Missing built app at {app}.")
    run("xcrun", "devicectl", "device", "install", "app", "--device", args.device, app)
    run("xcrun", "devicectl", "device", "process", "launch", "--device", args.device, args.bundle_id)


def parser() -> argparse.ArgumentParser:
    cli = argparse.ArgumentParser(description=__doc__)
    commands = cli.add_subparsers(dest="command", required=True)
    for name, help_text in (("check", "verify the installed toolchain"), ("pack", "export and smoke-test a review PCK"),
                            ("build", "export a signed development project on the Mac")):
        cmd = commands.add_parser(name, help=help_text)
        cmd.add_argument("--godot", help="path to the matching Godot executable")
        if name == "build":
            cmd.add_argument("--team-id", required=True)
            cmd.add_argument("--bundle-id", required=True)
            cmd.add_argument("--device", help="Xcode device ID to build, install and launch on")
            cmd.add_argument("--allow-provisioning-updates", action="store_true")
            cmd.add_argument("--release-template", action="store_true", help="use an optimized Godot release template")
    commands.add_parser("devices", help="list paired physical iPhones on the Mac")
    trace = commands.add_parser("record", help="record Instruments against the running app")
    trace.add_argument("--device", required=True)
    trace.add_argument("--duration", default="60s")
    trace.add_argument("--template", default="Game Performance")
    trace.add_argument("--output", type=Path)
    summary = commands.add_parser("summarize", help="summarize one in-app ABBA report")
    summary.add_argument("report", type=Path)
    return cli


def summarize(path: Path) -> None:
    report = json.loads(path.read_text(encoding="utf-8"))
    if report.get("schema") != 1 or report.get("order") != [2, 1, 1, 2] or len(report.get("rows", [])) != 48:
        raise ValueError("Expected a complete Godot WorldMap ABBA report.")
    groups = {}
    for row in report["rows"]:
        key = row["site"], row["hour"], row["weather"], row["camera_size"]
        groups.setdefault(key, []).append(row)
    if len(groups) != 12 or any([row["quality"] for row in rows] != report["order"] for rows in groups.values()):
        raise ValueError("Report did not repeat the same angles and conditions in ABBA order.")
    print(f"{report['platform']} · {report['renderer']}/{report['driver']} · {report.get('source_commit', 'unknown')}")
    print("Site | Hour | Cloud | FPS average (Full / Balanced) | Frame P95 ms | Viewport GPU P50 ms")
    for (site, hour, cloud, _), rows in groups.items():
        results = []
        for quality in (2, 1):
            pair = [row for row in rows if row["quality"] == quality]
            if any(not row["frame_ms"] for row in pair):
                raise ValueError("A segment has no frame samples.")
            gpu = [row["gpu_ms"]["p50"] for row in pair if row["gpu_sample_count"] > 0]
            results.append((median(row["mean_fps"] for row in pair),
                            median(row["frame_ms"]["p95"] for row in pair),
                            f"{median(gpu):.3f}" if len(gpu) == len(pair) else "n/a"))
        full, balanced = results
        minutes = round(hour * 60)
        print(f"{site} | {minutes // 60:02}:{minutes % 60:02} | {cloud:.0%} | "
              f"{full[0]:.1f} / {balanced[0]:.1f} | {full[1]:.2f} / {balanced[1]:.2f} | {full[2]} / {balanced[2]}")


def main() -> None:
    cli = parser()
    args = cli.parse_args()
    try:
        if args.command == "check":
            print(f"Godot {GODOT_VERSION}: {verify_godot(args.godot)}")
            if platform.system() == "Darwin":
                verify_xcode()
                run("xcrun", "devicectl", "list", "devices")
            else:
                print("iPhone build and Instruments run on the Mac.")
        elif args.command == "devices":
            verify_xcode()
            run("xcrun", "devicectl", "list", "devices")
        elif args.command == "record":
            verify_xcode()
            trace = args.output or BUILD_ROOT / datetime.now().strftime("iphone-%Y%m%d-%H%M%S.trace")
            trace = trace.expanduser().resolve()
            if trace.suffix != ".trace" or trace.exists():
                raise ValueError("Choose a new .trace destination.")
            trace.parent.mkdir(parents=True, exist_ok=True)
            run("xcrun", "xctrace", "record", "--device", args.device, "--template", args.template,
                "--time-limit", args.duration, "--attach", PRODUCT, "--output", trace)
        elif args.command == "summarize":
            sys.stdout.reconfigure(encoding="utf-8")
            summarize(args.report)
        else:
            export(args)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        cli.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
