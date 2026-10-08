# Original forest canopy V2

**Original authored study; awaiting user art review.** The visual reference is used for broadleaf layering, a compact green palette and blocky silhouettes; no reference geometry or texture has been copied. Project decisions remain in `docs/graphics/ART_DIRECTION.md` and its linked research.

`forest_canopy_v2.blend` is the editable source with four asset collections and an excluded diagnostic studio. `generator.py` reproduces the source, four GLBs, manifest, and Blender diagnostic render using Blender 5.2 background factory startup. It does not operate on a user's open scene.

Runtime files are in `game_mobile_3d/assets/environment/forest_canopy_v2/`:

| File | Geometry | Approximate size |
|---|---|---|
| `tree_oak_a.glb` | Asymmetric broadleaf crown, stepped leaf sprays, forked trunk and roots | 4.86 m high; 3.96 m wide |
| `tree_oak_b.glb` | Lower spreading crown, leaning trunk and roots | 4.32 m high; 3.78 m wide |
| `shrub_fern.glb` | Eight broad folded stepped fronds | 0.80 m high |
| `shrub_leaf.glb` | Six merged voxel leaf lobes | 0.84 m high |

Each tree has exactly `Bark` and `Leaves` mesh nodes with one material per mesh. Each shrub has a single `Leaves` mesh and material. All materials are opaque, single-sided, rough and nonmetallic. No external or packed textures. Flat normals and glTF `COLOR_0` are exported. Palette inputs are sRGB; `Color.color_srgb` stores their linear albedo, which is exported as linear vertex color. The base material color stays white.

All GLBs have metre scale and a bottom-centre root origin. Blender source object locations are only display offsets; local geometry retains the asset origin. The generator exports before applying display offsets. Blender Z-up is converted once to glTF/Godot Y-up.

To reuse in Godot, instance a GLB from the runtime directory. Keep its `.glb.import` and `vertex_color_import.gd` together: the post-import hook enables linear vertex-color albedo (otherwise the imported default material was white). Automatic mesh LOD is disabled in these study imports to preserve the stepped silhouette; mobile LOD remains unverified. The forest scene applies an additional palette shader; that shader and the scene's trunk collision are not embedded in the GLB. Add scene-appropriate collision when reusing. Materials can be used without the forest scene.

Leaf volume cells are 0.18 m for trees and 0.14 m for the leaf shrub. Hidden voxel faces are removed; adjacent coplanar faces with identical color are merged. Coherent rectangular color clusters avoid fine speckle. Roots and branch segments intersect intentionally; their internal intersections are not boolean-unioned. Fronds are closed, thick geometry with squared tips at least 0.1248 m wide.

`manifest.json` records exact bounds, triangles, primitive/material counts and export checks. `diagnostic_contact_sheet_final.png` is a Blender render inspected after refining the first crown pass. It is only an asset diagnostic: the parent task performs Godot integration, actual game-pixel review, lighting comparison and any phone performance checks. No mobile performance or artistic approval is claimed here.

Regenerate from the repository root with:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python 'blender/environment/studies/forest_canopy_v2/generator.py'
```
