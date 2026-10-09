"""Freeze the current graphics recipe; never replace a different frozen V5."""
from pathlib import Path
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game_mobile_3d"
PROFILE = GAME / "assets/graphics/meadow_daylight_v5"
ASSETS = GAME / "assets/environment/world_map_v1"
OUT = ROOT / "exports/graphics"
V1_SHA = "a6521b281f82bd3ab9be46a62d303cf968affb842b658a4d4120508f868963a4"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    v1 = OUT / "meadow_daylight_v1.zip"
    require(digest(v1.read_bytes()) == V1_SHA, "Frozen V1 checksum differs")
    sources = json.loads((ASSETS / "manifest.json").read_text(encoding="utf-8"))
    blend = ROOT / sources["source_blend"]
    blend_sha = digest(blend.read_bytes())
    require(len(sources["assets"]) == 18, "Review changes to the native asset set before freezing")
    for asset in sources["assets"].values():
        require(digest((ASSETS / asset["file"]).read_bytes()) == asset["sha256"],
                "Native GLB changed: " + asset["file"])

    files = [PROFILE / "README.md", PROFILE / "preset.tres"]
    for version in range(1, 5):
        folder = GAME / f"assets/graphics/meadow_daylight_v{version}"
        files += [folder / "README.md", folder / "preset.tres"]
    files += [GAME / "assets/graphics/meadow_daylight_v1/environment.tres"]
    files += list((GAME / "materials").glob("world_map_*.gdshader*"))
    files += [GAME / "materials/gameplay_cliff_cutaway.gdshaderinc"]
    files += [GAME / "scripts" / name for name in [
        "environment_look_preset.gd", "world_map_look.gd", "world_map_geometry.gd",
        "world_map.gd", "grassland_motion.gd", "gameplay_map.gd", "grassland_50x50.gd",
    ]]
    files += [GAME / "scenes" / name for name in [
        "WorldMap.tscn", "GameplayMap.tscn", "Grassland_50x50.tscn",
    ]]
    files += [GAME / "project.godot", GAME / "environment/GameplayMap.tres"]
    files += [ASSETS / "manifest.json", ASSETS / "native_asset_import.gd"]
    files += list(ASSETS.glob("*.glb")) + list(ASSETS.glob("*.glb.import"))
    files += [GAME / "tests" / name for name in [
        "review_world_map_grounding_v5.gd", "review_world_map_seams.gd", "validate_world_map.gd",
    ]]
    files += [GAME / "assets/maps/world_map/README.md"]
    files += [ROOT / name for name in [
        "AGENTS.md", "docs/graphics/ART_DIRECTION.md", "docs/graphics/RESEARCH.md",
        "blender/environment/studies/dungeons_ground_style_v2/WHITE_FLOWERS_V1.md",
        "blender/environment/studies/dungeons_ground_style_v2/read_user_litematic_layouts_v1.py",
        "scripts/import_world_map.py", "scripts/package_meadow_daylight_v5.py",
    ]]
    files += list((ROOT / "docs/validation/world_map/grounding_v5").glob("*.json"))
    # Preserve resource identity where it exists, but never archive generated Godot caches.
    files += [Path(str(p) + ".uid") for p in files if Path(str(p) + ".uid").is_file()]
    payload = {p.relative_to(ROOT).as_posix(): p.read_bytes() for p in sorted(set(files))}
    original_hashes = {name: digest(data) for name, data in payload.items()}

    # Exact preset/shader dependencies must be present. The host game's actors,
    # controllers and per-map runtime.json are deliberately outside this recipe.
    checked_refs = {}
    for name, data in payload.items():
        is_look_resource = (
            name.startswith("game_mobile_3d/assets/graphics/") and name.endswith(".tres")
        ) or name.endswith((".gdshader", ".gdshaderinc"))
        if is_look_resource:
            refs = re.findall(r'"res://([^"\r\n]+)"', data.decode("utf-8"))
            for ref in refs:
                require("game_mobile_3d/" + ref in payload, f"Missing look dependency: {name} -> {ref}")
            checked_refs[name] = refs

    manifest = {
        "version": "meadow_daylight_v5", "saved_at": "2026-10-09",
        "user_request": "Preserve the full current graphics recipe for many future Litematica maps",
        "scope": "Graphics recipe and integration references for the existing project; not a standalone game",
        "profile": "res://assets/graphics/meadow_daylight_v5/preset.tres",
        "renderer": "Mobile", "target_fps": 30, "phone_verified": False,
        "artistic_status": "Reuse requested; final visual approval not inferred",
        "future_map_policy": "Separate data/scene; regenerate height, path, root and soil fields from source placement",
        "importer_contract": "Current importer requires 100x100 RedWool bounds and supported block states; adapt other maps explicitly",
        "source_blend": sources["source_blend"], "source_blend_included": False,
        "current_source_blend_sha256": blend_sha,
        "native_assets_export_source_blend_sha256": sources["source_sha256_before"],
        "source_provenance": "Blender has later additive review edits; freeze the verified runtime GLBs without re-export",
        "native_glbs_verified": len(sources["assets"]), "frozen_v1_sha256": V1_SHA,
        "dependency_audit": {"scope": "Preset and shader resource references", "checked": checked_refs},
        "host_dependencies_not_bundled": [
            "Per-map runtime.json and original .litematic layout",
            "Existing player/enemy/weapon/animation/gameplay assets and their controller dependencies",
            "Blender source and unrelated asset guides linked by historical research",
        ],
        "files": original_hashes,
    }
    raw_manifest = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    payload["bundle_manifest.json"] = raw_manifest
    OUT.mkdir(parents=True, exist_ok=True)
    archive = OUT / "meadow_daylight_v5.zip"
    if archive.exists():
        with zipfile.ZipFile(archive) as old:
            require(set(old.namelist()) == set(payload) and all(old.read(n) == b for n, b in payload.items()),
                    "V5 is frozen. Save changed content as a new version; do not replace this archive.")
    else:
        staging = OUT / "meadow_daylight_v5.pending.zip"
        with zipfile.ZipFile(staging, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
            for name, data in sorted(payload.items()):
                entry = zipfile.ZipInfo(name, date_time=(2026, 10, 9, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                bundle.writestr(entry, data, compresslevel=9)
        with zipfile.ZipFile(staging) as check:
            require(check.testzip() is None, "Archive CRC validation failed")
            require(all(check.read(n) == b for n, b in payload.items()), "Archive contents differ")
        require(not archive.exists(), "V5 appeared during packaging; refusing overwrite")
        staging.rename(archive)
    with zipfile.ZipFile(archive) as check:
        require(check.testzip() is None, "Frozen archive CRC validation failed")
        require(all(check.read(n) == b for n, b in payload.items()), "Frozen archive contents differ")
    # Packaging must not alter runtime/source resources or the previous frozen package.
    for name, expected in original_hashes.items():
        require(digest((ROOT / name).read_bytes()) == expected, "Source changed during packaging: " + name)
    require(digest(blend.read_bytes()) == blend_sha, "Blender source changed during packaging")
    require(digest(v1.read_bytes()) == V1_SHA, "Frozen V1 changed during packaging")
    (PROFILE / "bundle_manifest.json").write_bytes(raw_manifest)
    sha = digest(archive.read_bytes())
    (OUT / "meadow_daylight_v5.sha256").write_text(sha + "  meadow_daylight_v5.zip\n", encoding="ascii")
    print(json.dumps({"archive": str(archive), "sha256": sha, "files": len(payload),
                      "native_glbs_verified": len(sources["assets"]),
                      "look_resources_audited": len(checked_refs), "source_and_runtime_unchanged": True,
                      "v1_preserved": True}, indent=2))


if __name__ == "__main__":
    main()
