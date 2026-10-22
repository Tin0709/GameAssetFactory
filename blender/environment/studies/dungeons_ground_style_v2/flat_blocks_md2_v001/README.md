**Later authorized gameplay trial:** Only the grass block is now used as the900-block terrain in the existing ActionsStuffWalkRunTest. Blender data is unchanged; dirt/stone standalone blocks remain in this review library. See `game_mobile_3d/scenes/dev/actions_stuff_research/grass_md2_v001/README.md` from the repository root. Earlier no-integration notes below describe the Blender refinement stage.

# MD2 blocks — subtle texture refinement, Pending

Latest user correction supersedes the first all-six-faces single-color trial: the grass block has a green top and the actual pack's stepped green cap over brown dirt sides, with a dirt bottom. Grass, dirt and stone now have very subtle broad pixel patches. Update the SAME three Pending objects in the SAME `dungeons_ground_style_v2.blend`; no new candidate, scene, project or Godot integration.

## Source and appearance

Actual local `Dungeons II Style0.7JE.zip` members supply16×16pixel patterns. Retain25%of their original color deviations around the dominant color, with no added procedural noise, bump, roughness variation, bevel or geometry relief. The exact side-overlay alpha boundary makes a3–6/16block grass cap. The top uses the original grayscale pattern tinted green. One packed80×20sRGB atlas shares four16px tiles with2px edge padding and nearest filtering; one material per cube, same1m geometry/origin/12triangles.

| Surface | Base sRGB | Provenance |
|---|---|---|
| Grass | `#4A6D29` | DominantRGB74/109/41 of actual `grass_block_side.png` green pixels, selected by `grass_block_side_overlay.png` alpha. The archive top is grayscale, but its side already contains green; this corrects the first trial's project-green substitution. |
| Dirt | `#865C3C` | DominantRGB134/92/60 in actual `dirt.png`. |
| Stone | `#888584` | DominantRGB136/133/132 in actual `stone.png`. |

Source/atlas palette and hashes are in `palette.json`; actual-model render is `preview.png`. `soft_texture.py` derives pixels; `refine_soft.py` is a guarded one-time refinement and must not be rerun over a completed refinement. Initial `build.py` remains historical and guarded.

## Open

```sh
python3 "$HOME/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" asset
```

Existing **Grass MD2 → Blocks MD2 — Soft Texture** has **ALL 3 BLOCKS**, **Grass**, **Dirt**, **Stone**, and **Opposite view**. Stable object/layer/catalog identifiers retain the first trial's Flat names for compatibility. Existing short/tall/Wind/Interaction controls remain. Current launcher recognizes `MD2_SOFT_BLOCKS_R2`, preserving older unsaved viewers rather than displaying their stale flat-only loaded data. Recovery-first same-window refresh remains available through `scripts/refresh_environment_viewer.py`.

## Checks

Saved/reopened; three1m cubes, same vertices/faces/transforms, outward flat normals, UVs place grass on top/cap and dirt below, one packed nearest texture node/material per block, native asset marks. Five block views and existing grass/Wind/Interaction routes pass. Native source-data comparison permits only the authorized three objects/meshes/materials; every other existing authored data block matches the pre-refinement file. Four derived hidden-layer Object caches are excluded as in the first trial; raw transforms/matrix basis remain compared. Fixed-camera native Blender render inspected. Backups/evidence: `.validation/soft_textured_blocks_v001/`. No production WorldMap, character, gameplay or approved Action changes. Pending user visual review.
