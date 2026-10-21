**Latest refinement — 2026-10-21:** [MD2 meadow and unified viewer](refinement_md2/README.md) adds pale seed tips, narrower stalks and green basal layers to the existing tall candidates. Short data remains exact. A single shared panel and combined row replace the previous two-panel review. Earlier tall appearance/checks below are historical.

# Tall Grass MD2 v001 — Pending Blender review

Four tall variants and two density arrangements are added to the SAME `dungeons_ground_style_v2.blend`. No Godot content, export, flowers, bushes or permanent separate library is included. Existing short grass was accepted as the baseline; subsequent explicit steering raises that set to approximately half a block. New tall candidates remain Pending.

## Open and review

```sh
python3 "$HOME/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" asset
```

The **Grass MD2** sidebar now has a **Tall Grass MD2 — Pending** panel alongside the retained short-grass controls. Choose the overview, A–D, two clusters, mixed planting, gameplay view, side/opposite views or comparison. Individual/field/comparison routes isolate only the relevant new display objects. **Short grass overview** selects the preserved short section; **Existing environment studies** selects the original environment layer. Local viewport cameras never replace the original scene camera. Old unsaved viewer windows stay untouched; the launcher recognizes the current tall-review bootstrap.

The native review leaves **Compare** open: half-block short grass, Tall A, previous V3 tall grass and the existing1.35m golden grass on identical source blocks. Old studies are references, not assets replaced by the new candidates.

## Current proportions and budgets

One block equals one metre. Crown width/length below measure the visible binary-alpha silhouette; transparent card margins may be larger.

| Candidate | Visible width × length | Visible height | Cards | Triangles |
|---|---:|---:|---:|---:|
| Tall_Grass_MD2_v001_A — Soft Meadow | 1.10 × 1.08 m | .78 m | 9 | 54 |
| Tall_Grass_MD2_v001_B — Open Fan | 1.22 × 1.12 m | .94 m | 10 | 60 |
| Tall_Grass_MD2_v001_C — Low Sweep | 1.12 × 1.14 m | .72 m | 8 | 48 |
| Tall_Grass_MD2_v001_D — Uneven Crown | 1.10 × 1.08 m | .87 m | 9 | 54 |
| Tall_Grass_MD2_Cluster_v001 — Meadow | 1.25 × 1.08 m | .87 m | 26 | 156 |
| Tall_Grass_MD2_Cluster_v002 — Upright | 1.18 × 1.10 m | .94 m | 36 | 216 |

Layered broad blade groups use three planar quad segments per card. Three higher core groups and lower, outward-curved edge groups provide height and density variation. Compact roots, mild asymmetry and lighter upper breakup distinguish the silhouettes. Cluster1combines three offset tufts; Cluster2uses four tighter upright tufts. No subdivision, modifier, rig or Action. One shared new material and packed128×128atlas; alpha coverage is roughly53–55% after tight cropping. Roots penetrate8mm into existing grass tops. Root card bounds on A–D are0.71–1.04m; visible bases are narrower than their transparent margins. Clusters review on ordinary2×2blocks. The mixed3×2m display has four tall bushes plus three linked short bushes.

Wind-anchor metadata exists on A–D, but this is a static review; no wind or gameplay implementation was added. Geometry and material budgets support later mobile work; no phone performance or overdraw benchmark is claimed.

## Verified source and authored adaptation

Read actual local `Dungeons II Style 0.7 JE/assets/minecraft/textures/block/tall_grass_top.png` and `tall_grass_bottom.png`. Both are16×16RGBA. The top has opaque grayscale141/160/175; the bottom141/160. Join top over bottom and crop `(2,3,15,32)` to the occupied13×29region. The pack itself supplies texture artwork, not evidence of official Dungeons II card geometry or rendering behavior.

`make_texture.py` retains that silhouette, provides mirrored and selectively tip-trimmed siblings, and uses the established short-grass green mapping. Bottom rows converge to the existing V3 terrain RGB84/130/52. The shared four-level mapping includes146from the short-grass family; the tall source does not contain that gray. Nearest2× scaling, binary alpha and color-filled transparent gutters retain clean pixels without blur or random noise. `texture_manifest.json` records source hashes and exact atlas regions. New clump geometry is an original authored interpretation of this texture style.

The new material is an independent copy of the current short-grass lighting setup: two-sided binary cutout, matte diffuse plus thin-leaf transmission and terrain-up weighted normals. Original materials and images remain byte-for-byte equal under native content fingerprints.

## Explicit short-grass height refinement

All four `Short_Grass_MD2_v001_A`–`D` and `Short_Grass_MD2_Cluster_v001` now reach **0.500m visible height**. Only positive vertex Z is scaled; roots below zero, all XY, topology, UVs, weights, material and texture remain exact. Linked instances follow the same mesh change. The trimmed transparent card tip of C reaches.620m geometrically but renders no pixels above.500m. Its silhouette and all other short silhouettes retain their original at-least1×1m visible horizontal size.

Source checks temporarily restore baseline short coordinates, compare all pre-existing native fingerprints including evaluated dimensions, then restore the requested height. This catches unrelated edits while allowing only the user-authorized change. No new short candidate or animation is created.

## Verification and reproduction

- `validation.json`: fresh-open417original objects, old collections, old scene/camera and short registry preserved, zero Actions/new scenes; explicit short-Z formula error under3e-8m; original meshes/materials/images preserved except requested short Z; tall topology/material/height/footprint and15selector routes checked.
- `native_viewport_validation.json`: actual native Material Preview redraws, Grass MD2 sidebar, isolated object visibility, short/original section switching and final Compare.
- `review/`: source-derived texture board, isolated candidate/cluster, grouped/gameplay/opposite/side, overall and comparison renders, plus native UI captures.
- `.validation/tall_grass_md2_v001/file_preservation.json`: file hash audit with an explicit library/short-height/support-documentation allowlist; all Godot files and every other Blender library remain unchanged.
- Two new launcher tests were observed failing before implementation and passing afterward; prior short-viewer/bootstrap/dev checks also pass.

`build.py` creates an additive candidate in ignored validation storage, guards the original library hash and refuses an existing tall root. Fresh-open checks run before atomic publication to the requested library. It must not be rerun against the completed file. Baseline backup, native fingerprints and raw short coordinates are in `.validation/tall_grass_md2_v001/`. `verify.py` is read-only by default against the saved central library; `render.py` and `review_native.py` change only unsaved presentation state. Keep candidates Pending and stop here for user review.
