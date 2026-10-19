# Permanent Weapon Showcase

**2026-10-19 — Shotgun multi-view proportion refinement:** the same Pending [Sand Block shotgun](../shotgun_sand_block_v1/README.md) now follows the user's newer reference sheet: a higher/slimmer continuous pump with shallow grooves and a broad lower bevel, stepped stock cavity/neck, shorter rearward grip and smaller guard, finer rail, compact magazine and octagonal brass caps/bore openings. Grip origin is corrected to the actual revised handle and support markers follow the new pump. 4,812 triangles / one 256 px atlas; prior source and aligned side comparisons are in `.validation/shotgun_sand_block_reference_refinement_20261019/`. Previous weapons/approval states remain preserved; no gameplay integration.

**2026-10-19 — Sand Block shotgun tube spacing:** the same Pending shotgun now raises the lower tube and its four collars together by22mm, with the bridge refitted. Saved geometry has1.5mm clearance at the collars and6mm between the bare tubes, following the user's closer-spacing reference. Previous source is backed up under `.validation/shotgun_sand_block_close_tubes_20261019/`; other sources, markers and approval records are preserved.

**2026-10-19 — Tactical Sand Block shotgun:** [new reference shotgun](../shotgun_sand_block_v1/README.md) is registered Pending and selected by default in this same library. It has a stepped open sand stock, grooved sand pump, graphite receiver/dual tubes, a long block rail and four red/brass shells in a side saddle. Six active models; previous sources and archived records are preserved. The user's preceding “ok tốt rồi” records Pistol Sand Block V1 as visually Approved in metadata only; no gameplay integration or source edits.

**2026-10-19 — Pistol Sand Block V1 detail review:** the same Pending pistol now has stronger flat graphite pixel clusters, a stepped rear slide roof, a lower barrel hood with a narrow warm crown, a straighter stepped trigger, and connected faceted grip panels seated on a wider magazine floorplate. Latest feedback increases the size and light/dark contrast of the graphite patches for clearer visibility. Dimensions and markers are unchanged. [Source and eight inspection views](../pistol_sand_block_v1/README.md); previous pistol/library are backed up under `.validation/pistol_sand_block_detail_20261019/` and `.validation/pistol_sand_block_dark_texture_20261019/`. Reopen an existing viewer to load the saved refinement.

**2026-10-19 — Pistol Sand Block V1:** [new user-reference pistol](../pistol_sand_block_v1/README.md), sand frame and graphite slide, is registered Pending and selected by default. The same library now contains five active models; previous weapon entries and sources are preserved.

**2026-10-19 — Red-orange scope tint:** both V1 glass lenses now use the user's requested red-orange color. Transmission, reflectivity, hollow housing and all geometry are retained.

**2026-10-19 — Sand Block scope glass:** the same Pending V1 now has an open metal optic tunnel, recessed front/rear lens seats and two separate transmitting biconvex glass lenses. GLB retains glass transmission and alpha blending. The detail pass and all prior weapons remain preserved; dimensions/markers are unchanged. Reopen an existing viewer window to load the updated saved model.

**2026-10-19 — Sand Block V1 detail review:** the same Pending entry now includes chamfered taller vents, recessed rail teeth, front/side sight apertures, warm optic/muzzle trim, stock/grip/magazine seams and finer pixel clusters after a second comparison with the user reference. Its dimensions and markers are unchanged; previous V1 is backed up under `.validation/rifle_sand_block_detail_20261019/`.

**2026-10-19 — New reference rifle:** [Rifle — Sand Block V1](../rifle_sand_block_v1/README.md) is registered as Pending and selected on open. The active list now has four models. This distinct sand/graphite block rifle follows the user's supplied multi-view reference; previous sources and approval states are preserved. The three-model/default-shotgun descriptions below record the earlier library state.

**Latest rifle selection — 2026-10-12:** Rifle Stylized V2 is the explicitly selected preferred model/reference. Its ready and10deg back previews now use uniform1.05 scale, preserving source proportions instead of legacy width compression. All other weapon geometry and mount behavior are preserved. The concurrent Pistol Stylized V2 registration/default selection remains intact. Actual Godot test uses the existing55deg Chest mount, not the10deg showcase alternative. [Candidate, rendered fit, validation and remaining overlap limits](../rifle_stylized_v2/godot_integration/README.md). Selection is not production-replacement approval.

Open **Open_Weapon_Showcase.cmd**. It launches `Weapon_Showcase.blend` in a separate Blender 5.2 window, explicitly loads the sidebar script and opens **N → Weapon Library**. The list contains only the three current designs: Shotgun Stylized V2, Pistol Stylized V2 and Rifle Stylized V2. Future new designs will join this same list. Select a row and choose **Standalone**, **Character ready**, or **Character holster**. Left / Right / Front / Back / 3/4 set the inspection angle; normal orbit, pan and zoom remain available. Reopen through the launcher if an older window only shows Item / Tool / View / Animation tabs.

The launcher does not install an add-on, change preferences, enable global automatic script execution, or replace Animation Showcase. Opening the blend directly without the launcher preserves all native `WEAPON_…` collections and the selected model; the custom panel requires the launcher (or explicitly running `gaf_weapon_library.py`). This is deliberate and visible, not an implicit dependency on auto-executed embedded text.

## Registered models

3 active entries: `Rifle_Stylized_V2` (Preferred), `Pistol_Stylized_V2` (Pending) and `Shotgun_Stylized_V2` (Pending). The shotgun opens selected. Per the user's 2026-10-12 request, the 16 older entries are removed from the selection list and stored under `archived_weapons` in `weapon_manifest.json`; their metadata, source files and exports remain preserved. Future new designs register in this same active list. Gameplay integration remains Pending.

List cleanup verification: all 35 recorded source/export files retain their hashes, all 19 original entry records retain their fields/statuses across active and archived records, and the saved showcase passes 45 selection/mode/view combinations. The previous showcase and manifest are backed up under `.validation/weapon_showcase_v2/list_cleanup_20261012_172503/`. See `list_cleanup_verification.json` and `library_verification.json`.

## Current shotgun review — 2026-10-12

New original Stevens-inspired `Shotgun_Stylized_V2`: long faceted barrel, stepped receiver, brown traditional stock and independently moving wood pump. 0.978m long, 1,084 triangles, two rigid meshes, one material/64×64 atlas. Selected initially in this SAME showcase. [Source/export, previews, pump travel and validation](../shotgun_stylized_v2/README.md). Existing ready pose needs future left-hand alignment to the pump; static stowed preview is available. No character Action or production edit.

Latest requested correction raises the lower assembly10.3mm: barrel/tube gap2.45mm and barrel/wood-pump gap0.79mm, with55mm pump travel preserved. Earlier wider-gap candidate is backed up; other entries are unchanged.

## Current rifle review — 2026-10-12

The new **Pistol_Stylized_V2** is independently selectable as **Pending**, with a muted brown grip and closed trigger joints. See [its source, export, previews and fit limitations](../pistol_stylized_v2/README.md). Future registrations default to the newly registered weapon in this SAME library.

The latest user correction asks for a longer rifle matching the supplied M4A1 image. The current V2 uses that image's proportions: long angular stock, shallow silver/gray receiver, open carry handle, broad eight-rib guard, triangular front sight, extended stepped barrel, curved magazine and small identification markings. The compact candidate is preserved in the archive, outside the active selection list.

Measured current asset: **1.200 m long × 0.093 m wide × 0.3618 m tall**, **1,620 triangles**, two rigid meshes, two draw surfaces, one opaque material and one embedded **1024×512** nearest-sampled atlas (about 78KB PNG). Body is 1,476 triangles; detachable magazine is 144. Identification planes are intentionally open, slightly offset quads joined into the same meshes/material; other geometry has closed component surfaces. Small structural bevels and flat normals retain the block style. This exceeds the old 900-triangle rifle target to retain silhouette detail, chamfers and a detachable magazine; it remains a small prop budget, not a measured phone-performance claim.

Latest corrections add a layered stock brace, receiver details, shallow guard bands and readable steel/graphite colors. Clean baked sans-serif lettering replaces the rejected pixel numbers. The magazine serial runs parallel to its base; two equally spaced curved black bands share aligned ends and clear margins above the number. Its feed mouth overlaps the receiver. Carry-handle feet overlap the receiver by 1.35mm before chamfering, closing the gap while preserving the open window. Palette UVs stay inside their swatches. User steering subsequently darkens the barrel and all matching fittings to sRGB (105,117,126), and reduces the hollow rectangular muzzle cap to 39.2mm long × 32mm wide × 25mm tall (about 30% smaller/thinner). The muzzle target and overall rifle length stay fixed.

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

Verification: `test_library.py` reopens the saved file and tests all 3 active entries × three modes × five views (45 combinations), newest/current-design list order, default selection, camera framing, isolation, distinct fit poses, no Actions, Windows path classification and exclusive locking. `verify_assets.py` records the earlier rifle/production comparison and requires the archived production entry for that historical comparison. Per-asset verification scripts check binary GLB structure, markers, fit diagnostics and protected hashes. `render_review.py` produces actual Blender pixels. These are Blender/export checks, not Godot transition or phone benchmarks. **Awaiting user visual approval before production replacement.**
