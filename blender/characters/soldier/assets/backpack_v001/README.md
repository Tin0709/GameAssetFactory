# SOLDIER Backpack v001 — Pending

One standalone equipment asset, based on the supplied backpack reference. Stored in `../../showcase/SOLDIER_Asset_Library.blend` under `SOLDIER_ASSETS/04_EQUIPMENT/SOLDIER_Backpack_v001_PENDING`, catalog `SOLDIER/Equipment`. **Not fitted, parented, attached or worn by the character.** No Godot integration.

## Appearance

Layered brown canvas shell with a broad upper flap, twin lower front pockets, side pockets, black compression/webbing straps, polygonal shoulder loops, top carry handle and gray metal tabs/adjusters. The two rear square adjusters and bottom buckle have real open centers.

Latest user corrections prioritize the small Minecraft-like details in the reference: individual stepped corner blocks, segmented edge piping, chunky folded pocket lips, raised fabric breaks, canvas crown blocks, segmented shoulder/back padding and square metal details. Broad surfaces remain readable.

An original nearest-filtered1024×1024pixel atlas supplies dusty earth-brown cloth, fine desaturated gray-brown flecks, small warm fibers, worn edges and scratched/riveted steel. The supplied upper cloth sample has medianRGB116/89/65; this palette guides the original texture painting and studio color adjustment. The sheet is a visual reference, not a sourceUV asset.

## Review

Opening review scene: **SOLDIER_BACKPACK_REVIEW**. Character review remains **SOLDIER_ASSET_LIBRARY** in the same file. Six named cameras use `BPK_` prefixes. `review_four_views.jpg` and `renders/` contain actual Blender front, three-quarter, side and back views. Reference, atlas and four-view sheet are packed.

The backpack is one static mesh, one material, 3,688vertices/5,760triangles, approximately 0.544×0.392×0.667m. All part solids are closed. No rig or Action is added. Character geometry, UVs, weights, rig and material assignments are fingerprint-checked before/after and after reopening.

Use the existing `open_blender_viewer.py soldier` command. An already-open file retains its in-memory state; use File>Revert in the SOLDIER window to read the latest saved library. Do not save an outdated window over new assets.

## Focused rebuild

Run `make_atlas.py` with Pillow Python, `build_backpack.py` with Blender, `package_review.py` with Pillow, and `verify_backpack.py` with Blender. Only this same Pending equipment entry is refined. Other entries are preserved. The initial skin-only `build_library.py` now refuses to overwrite a library containing additional assets. Retain initialized editor types when building in background; see the library's native-opening fix notes.
