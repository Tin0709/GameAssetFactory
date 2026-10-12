# Permanent Weapon Showcase

Open **Open_Weapon_Showcase.cmd**. It launches `Weapon_Showcase.blend` in a separate Blender 5.2 window and explicitly loads the local sidebar script on every launch. Press **N → Weapon Library**, select a row, and choose **Standalone**, **Character ready**, or **Character holster**. Left / Right / Front / Back / 3/4 set the inspection angle; normal orbit, pan and zoom remain available.

The launcher does not install an add-on, change preferences, enable global automatic script execution, or replace Animation Showcase. Opening the blend directly without the launcher preserves all native `WEAPON_…` collections and the selected model; the custom panel requires the launcher (or explicitly running `gaf_weapon_library.py`). This is deliberate and visible, not an implicit dependency on auto-executed embedded text.

## Registered models

17 independent entries: M4A1 blocky V1–V4, Pistol V1–V4, Shotgun V1–V4, three preserved production R13 GLBs, current `Rifle_Stylized_V2`, and its early compact checkpoint. `weapon_manifest.json` records the actual source path and SHA256 for every entry. Historical versions remain Pending where individual approval was not recorded; the production entries retain their existing approved-geometry status. Both V2 candidates are Pending.

## Current rifle review — 2026-10-12

The latest user correction asks for a longer rifle matching the supplied M4A1 image. The current V2 uses that image's proportions: long angular stock, shallow silver/gray receiver, open carry handle, broad eight-rib guard, triangular front sight, extended stepped barrel, curved magazine and small identification markings. The compact candidate is preserved and selectable.

Measured current asset: **1.200 m long × 0.094 m wide × 0.3618 m tall**, **1,140 triangles**, two rigid meshes, two draw surfaces, one opaque material and one embedded **1024×512** nearest-sampled atlas (about 22KB PNG). Body is 996 triangles; detachable magazine is 144. Identification planes are intentionally open, slightly offset quads joined into the same meshes/material; other geometry has closed component surfaces. Small structural bevels and flat normals retain the block style. This exceeds the old 900-triangle rifle target to retain silhouette detail and a detachable magazine; it remains a small prop budget, not a measured phone-performance claim.

Latest corrections replace the rejected coarse pixel numbers with clean baked sans-serif lettering and larger serial margins. The magazine label stays inside its face. Carry-handle feet overlap the receiver by 1.35mm, closing the reported gap without changing the large open handle window. Palette UVs sit safely inside their swatches, away from the red safety marks.

Source/export: `../rifle_stylized_v2/Rifle_Stylized_V2.blend` and `.glb`. The source defaults to an uncluttered material viewport; studio lighting and inspection cameras live in the central showcase. Review PNGs are in `../rifle_stylized_v2/review/`. The build scripts preserve earlier iterations under the compact checkpoint and `.validation/weapon_showcase_v2/`.

## Character fit and boundaries

Ready and stowed static meshes are evaluated from the existing full-arm R13 source at **F1** and the actual stowed interval **F62**, without importing or creating any Action in the showcase. Right grip and left guide keep the established grip/support coordinates. Blender +Y forward / +Z up converts once to Godot -Z forward / +Y up. Nine exported nodes include the six requested names plus legacy `Grip_Point`, `Support_Hand_Point`, `Muzzle_Point`. The magazine is an independent child with a feed-mouth pivot. `HolsterAttach` stays at the grip anchor for the existing socket contract.

The original production back mount is actually a steep 55° diagonal. The latest brief asks for horizontal with a slight diagonal, so **only Pending V2** trials a separate **10°** mount in the showcase. It sits behind the torso to clear the resting arms; production mounts remain unchanged on their own entries. This static preview matrix is recorded in the manifest and is not wired into production.

Current fit checks find no V2 head/chest/off-hand surface intersections in ready pose and no head/chest/arm intersections in its stowed preview. The approved holding pose already overlaps the dominant arm at the grip/shoulder; V2 retains contact in that region. It is not certified collision-free across recoil, reload, aiming, locomotion or holster transitions. The longer muzzle and lower sightline require future gameplay/aiming review before integration. Triangle overlap counts are diagnostics, not penetration depth or a visual approval metric.

No production asset, controller, weapon script, approved animation, source rig, character proportion or Animation Showcase was changed by this task. Separate concurrent locomotion work changed three Godot scripts while the preservation check ran; `asset_verification.json` reports them rather than attributing them to this weapon work.

## Future weapon workflow (required)

Every future rifle/pistol/shotgun version must be registered in **this same showcase** as Pending. Do not create another per-weapon showcase or overwrite an approved source. Author a distinct versioned `.blend` with one `WEAPON_EXPORT` collection and a grip-centered root, then run:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python 'blender/weapons/showcase/register_weapon.py' -- --id rifle_next_v1 --kind Rifle --label 'Rifle — Next V1' --source 'blender/weapons/rifle_next/rifle_next_v1.blend'
```

Registration validates the source, backs up manifest/showcase, forces Pending, and rebuilds the SAME showcase automatically. Existing entries and source hashes are preserved. Updates use a single-writer lock and compare current hashes before saving. A failed registration restores only its own unchanged manifest write. After a native Blender crash, inspect `.weapon_library.lock` and its PID before removing a stale lock; do not interrupt a live update.

Refresh existing snapshots with `build_showcase.py` in a fresh background Blender process. A changed source hash stops the update for inspection. Approved sources must never be silently replaced. Reopen via the launcher after rebuilding; an already open Blender window retains its in-memory copy until reopened.

Verification: `test_library.py` reopens the saved file and tests all 17 entries × three modes × five views (255 combinations), camera framing, isolation, distinct fit poses, no Actions, Windows path classification and exclusive locking. `verify_assets.py` checks binary GLB structure, markers, fit diagnostics and protected hashes. `render_review.py` produces actual Blender pixels. These are Blender/export checks, not Godot transition or phone benchmarks. **Awaiting user visual approval before production replacement.**
