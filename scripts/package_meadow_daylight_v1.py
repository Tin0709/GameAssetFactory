"""Freeze the requested look with source hashes. Never overwrite a different V1."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game_mobile_3d"
PROFILE = GAME / "assets/graphics/meadow_daylight_v1"
ASSETS = GAME / "assets/environment/world_map_v1"
OUT = ROOT / "exports/graphics"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    sources = json.loads((ASSETS / "manifest.json").read_text(encoding="utf-8"))
    blend = ROOT / sources["source_blend"]
    assert digest(blend) == sources["source_sha256_before"], "Saved Blender source differs; inspect before releasing"
    for asset in sources["assets"].values():
        assert digest(ASSETS / asset["file"]) == asset["sha256"], asset["file"]
    files = [PROFILE / name for name in ["README.md", "preset.tres", "environment.tres"]]
    files += [GAME / "scripts" / name for name in ["environment_look_preset.gd", "world_map_look.gd", "world_map_geometry.gd", "world_map.gd", "grassland_motion.gd"]]
    files += list((GAME / "materials").glob("world_map_*.gdshader*"))
    files += [GAME / "materials/gameplay_cliff_cutaway.gdshaderinc"]
    files += [ASSETS / "manifest.json", ASSETS / "native_asset_import.gd"]
    files += list(ASSETS.glob("*.glb")) + list(ASSETS.glob("*.glb.import"))
    files += [GAME / "tests/review_world_map_seams.gd", GAME / "assets/maps/world_map/README.md"]
    files += [ROOT / "blender/environment/studies/dungeons_ground_style_v2/WHITE_FLOWERS_V1.md"]
    payload = {path.relative_to(ROOT).as_posix(): path.read_bytes() for path in sorted(set(files))}
    manifest = {
        "version": "meadow_daylight_v1", "saved_at": "2026-10-09",
        "user_request": "Save the current graphics for reuse on future maps",
        "artistic_status": "reuse requested; final visual approval not inferred",
        "phone_verified": False, "renderer": "Mobile", "target_fps": 30,
        "profile": "res://assets/graphics/meadow_daylight_v1/preset.tres",
        "source_blend": sources["source_blend"], "source_blend_sha256": digest(blend),
        "files": {name: hashlib.sha256(data).hexdigest() for name, data in payload.items()},
    }
    raw_manifest = (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    payload["bundle_manifest.json"] = raw_manifest
    OUT.mkdir(parents=True, exist_ok=True)
    archive = OUT / "meadow_daylight_v1.zip"
    if archive.exists():
        with zipfile.ZipFile(archive) as old:
            assert set(old.namelist()) == set(payload) and all(old.read(n) == b for n, b in payload.items()), "V1 is already frozen. Save changed content as a new version."
    else:
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
            for name, data in payload.items():
                entry = zipfile.ZipInfo(name, date_time=(2026, 10, 9, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                bundle.writestr(entry, data)
    with zipfile.ZipFile(archive) as check:
        assert check.testzip() is None
        assert all(check.read(n) == b for n, b in payload.items())
    (PROFILE / "bundle_manifest.json").write_bytes(raw_manifest)
    sha = digest(archive)
    (OUT / "meadow_daylight_v1.sha256").write_text(sha + "  meadow_daylight_v1.zip\n", encoding="ascii")
    print(json.dumps({"archive": str(archive), "sha256": sha, "files": len(payload), "native_glbs_verified": len(sources["assets"]), "source_preserved": True}, indent=2))


if __name__ == "__main__":
    main()
