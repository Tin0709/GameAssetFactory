# Flat Blocks MD2 v001 — Pending Blender review

Three additive1×1×1m blocks, bottom-center origins, six planar faces/12triangles each, one matte solid material on all six faces. No texture nodes, UV pattern, bevel, noise, displaced detail, animation or Godot export. Saved in the existing `dungeons_ground_style_v2.blend`, original scene and new isolated `Flat Blocks MD2` review layer. All prior candidates, native data and grass/wind/interaction routes remain.

## Color provenance

| Block | Solid sRGB | Evidence |
|---|---|---|
| Grass | `#548234` | Exact archive grass top is grayscale, dominantRGB148/148/148, and the archive provides no biome colormap. Use the dominant green of the current library `v3_textures/grass_top_0.png` as an explicitly authored project tint adaptation. This green is not claimed to be embedded in the pack. |
| Dirt | `#865C3C` | Most frequentRGB134/92/60 in actual archive `assets/minecraft/textures/block/dirt.png`. |
| Stone | `#888584` | Most frequentRGB136/133/132 in actual archive `assets/minecraft/textures/block/stone.png`. |

Exact local ZIP/member hashes and color method: `palette.json`. Correct sRGB→linear conversion feeds the Blender Base Color; normal lighting still shades cube faces. The actual-model render is `preview.png`.

## Open and select

```sh
python3 "$HOME/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" asset
```

In the existing **Grass MD2** tab, **Flat Blocks MD2 — Pending** offers **ALL 3 BLOCKS**, **Grass**, **Dirt**, **Stone**, and **Opposite view**. Existing short/tall/Wind/Interaction controls remain below. Native assets use catalog **Environment/Flat Blocks MD2 Pending**.

The launcher recognizes the new flat-block bootstrap, preserving older unsaved viewers rather than reusing their stale loaded data. Same-window refresh remains available through `scripts/refresh_environment_viewer.py`, which first writes a recovery copy. No auto-run preferences change.

## Essential checks

Saved/reopened; correct1m dimensions, outward normals, rigid flat faces, one material/no texture nodes, exact palette and native asset marks. All new routes plus existing short/tall/close/Wind/Interaction routes pass. Original objects/transforms, meshes/UVs/materials/images/lights/cameras/worlds/render settings match the pre-edit library. Reopen preservation compares stored data; four derived Object caches (bounds, dimensions, local/world matrix) are excluded because hidden layers initialize them lazily. Stored transforms and matrix basis are still compared. The new blocks' dimensions are independently asserted after evaluation.

Evidence/backups: `.validation/flat_blocks_v001/` from repo root. Other pre-existing Blender/game files remain byte-identical except the shared sidebar module and additive asset catalog. No production WorldMap or gameplay changes. Await user color/design review; no prior asset is replaced or approval promoted. Do not rerun the guarded build over the completed library.
