# Short Grass MD2 v001 — Pending Blender review

Added to the existing `dungeons_ground_style_v2.blend`, not a separate library. No Godot export or integration. Original grass, flowers, ground, materials, lighting and source camera remain unchanged.

Open from any terminal:

```sh
python3 "$HOME/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" asset
```

The **Grass MD2** sidebar opens automatically. Select A–D or Cluster, Grouped, Gameplay, Opposite, or Beside current grass. **Existing environment studies** restores the original view layer. Controls select local viewport cameras; they do not replace the original scene camera. No global auto-run preference is changed. The launcher preserves older open windows and opens/reuses the version with these controls.

## Candidates

One block is one metre. Every bush spans at least one block in both horizontal axes, including its visible cutout silhouette. Heights were retained when the user requested wider bushes.

| Asset | Mesh width × length | Height above ground | Cards | Triangles |
|---|---:|---:|---:|---:|
| Short_Grass_MD2_v001_A — Low Cushion | 1.14 × 1.11 m | .194 m | 8 | 32 |
| Short_Grass_MD2_v001_B — Broad Fan | 1.20 × 1.14 m | .234 m | 7 | 28 |
| Short_Grass_MD2_v001_C — Soft Rosette | 1.10 × 1.12 m | .164 m | 9 | 36 |
| Short_Grass_MD2_v001_D — Uneven Tuft | 1.10 × 1.12 m | .274 m | 7 | 28 |
| Short_Grass_MD2_Cluster_v001 | 1.40 × 1.35 m | .208 m | 39 | 156 |

A–D have three central cards and lower outward-spreading cards with gentle bend, varied azimuths and heights. Cluster combines five offset tufts into one mesh. Two planar quads per card; one shared material and one packed128×64atlas. No subdivision, modifier, rig or new Action. Bottom-centred origins, baked dimensions, unit object scales. Roots penetrate the ground about8mm; six full-size bushes demonstrate spacing on a3×2m ground area, alongside individual one-block platforms and an ordinary2×2base for Cluster.

Native assets are under `Vegetation_Grass_Pending/MD2_Short_Grass_v001_PENDING`, catalog **Environment/Short Grass MD2 Pending**. The new `Short Grass MD2` view layer isolates the review within the existing scene. The original layer excludes only the new review root.

## Verified reference and adaptation

Local reference: `local_references/Dungeons II Style 0.7 JE.zip`, extracted `assets/minecraft/textures/block/short_grass.png`. The actual source sprite is16×16RGBA, with four opaque grayscale values141/146/160/175; its occupied region is16×10pixels. This is resource-pack artwork, not verified official Dungeons II geometry or rendering behavior.

`make_texture.py` crops the actual silhouette, creates mirrored/trimmed siblings, maps the four values to subdued greens, and converges the bottom two rows toward the existing V3 grass-top RGB84/130/52. Nearest2× scaling and binary alpha preserve crisp pixels. Transparent gutters retain adjacent RGB to avoid fringes. Source hashes, crop regions and palette are in `texture_manifest.json`. The new layered card shapes are an authored interpretation, not an undocumented source mesh.

Two-sided binary cutout uses nearest filtering, rough diffuse plus restrained thin-leaf transmission, and terrain-up weighted normals. Both leaf lobes use the same upward normal. Backface-based normal flipping caused dark cards in trials and was removed. Existing materials remain exact. The UI uses the established forest Material Preview; rendered previews use the separate new review lights. No performance claims are made for a phone; triangle/material budgets are the only mobile evidence here. Wind anchor metadata exists, but active wind is outside this static review.

## Checks and evidence

- `validation.json`: fresh-open topology, material, shared terrain, native camera routes and original366objects/161meshes/28materials/25images/14cameras/6lights/world/scene preservation.
- `visible_footprints.json`: opaque texel support; minimum horizontal span is approximately1.020m.
- `native_viewport_validation.json`: eleven actual native selector/draw routes, active Grass MD2 sidebar, original scene camera preserved, final Overview left open.
- `review/`: native UI captures, Overview, Grouped, Gameplay, individual A and opposing-light previews.
- `.validation/short_grass_md2_v001/file_preservation.json`:8,793existing files checked; only the authorized central Blender library and its study-index documentation changed. Godot files and every other `.blend` remain byte-identical.
- Launcher:2focused stale-window/UI checks,6viewer bootstrap tests and16dev launcher tests passed.

Read-only checks use Blender `--background --factory-startup --disable-autoexec --python` with `verify.py` or `verify_visible_footprints.py`. `render.py` renders saved data without saving camera/settings. `review_native.py` exercises controls and captures the actual window without saving.

`build.py` is a guarded additive construction record: it intentionally refuses to overwrite an existing MD2 collection. It requires the recorded pre-study library baseline and preservation evidence; do not run it against this completed library. `manifest.json` retains raw card-construction parameters before the final baked horizontal footprint fit. Keep all five assets Pending until explicit user approval. Stop here for Blender review; no tall grass, flowers or gameplay work is included.
