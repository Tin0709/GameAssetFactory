# SOLDIER Backpack v001 — Pending

One standalone equipment asset, based on the supplied backpack reference. Stored in `../../showcase/SOLDIER_Asset_Library.blend` under `SOLDIER_ASSETS/04_EQUIPMENT/SOLDIER_Backpack_v001_PENDING`, catalog `SOLDIER/Equipment`. **Not fitted, parented, attached or worn by the character.** No Godot integration.

## Appearance

Layered brown canvas shell with a broad upper flap, twin lower front pockets, side pockets, black compression/webbing straps, polygonal shoulder loops, top carry handle and gray metal tabs/adjusters. The two rear square adjusters and bottom buckle have real open centers.

Latest user direction supersedes the earlier dense grain and many small blocks: remove fine speckles, use quiet broad pixel patches with small color differences, and simplify repeated relief. Main faces are clean, with a few larger corner/fold steps. The current backpack has236parts and3,744triangles (previously404parts/5,760triangles).

A shared nearest-filtered512×512atlas is painted at32logical pixels per tile, using only a few close tones for brown cloth and plain gray metal. No granular dirt/noise layer or tiny fiber marks remain. Main flap adjacent-pixel variation falls from9.8384 to0.0679 on a normalized128pixel sample; mean color stays close. Four square rivets and broad steel edge accents remain readable.

## Review

Opening review scene: **SOLDIER_BACKPACK_REVIEW**. Character review remains **SOLDIER_ASSET_LIBRARY** in the same file. Six named cameras use `BPK_` prefixes. `review_four_views.jpg` and `renders/` contain actual Blender front, three-quarter, side and back views. Reference, atlas and four-view sheet are packed.

The backpack is one static mesh, one material, 2,344vertices/3,744triangles, approximately 0.544×0.392×0.667m. All part solids are closed. No rig or Action is added. Character geometry, UVs, weights, rig and material assignments are fingerprint-checked before/after and after reopening.

Use the existing `open_blender_viewer.py soldier` command. It explicitly loads the **SOLDIER Library** sidebar (N key), with Character/Equipment selectors, Pending status and six camera buttons. UI selection changes only review scenes/cameras and selection; it never fits assets or changes transforms. An already-open file retains its in-memory state; use File>Revert in the SOLDIER window to read the latest saved library. Do not save an outdated window over new assets.

## Focused rebuild

Run `make_atlas.py` with Pillow Python, `build_backpack.py` with Blender, `package_review.py` with Pillow, and `verify_backpack.py` with Blender. Only this same Pending equipment entry is refined. Other entries are preserved. The initial skin-only `build_library.py` now refuses to overwrite a library containing additional assets. Retain initialized editor types when building in background; see the library's native-opening fix notes.
