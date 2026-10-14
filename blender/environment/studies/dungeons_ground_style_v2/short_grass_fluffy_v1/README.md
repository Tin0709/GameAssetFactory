# ShortGrass_Fluffy_v1 — PENDING REVIEW

Primary review location: **`../dungeons_ground_style_v2.blend`**, not a separate showcase. All prior environment objects, meshes, materials, images, cameras, lights, world, collections, text and armatures are preserved. No main-map or approved grass replacement.

In the Outliner, expand **Vegetation_Grass_Pending**:

| Child collection | Contents |
|---|---|
| `01_ShortGrass_Fluffy_v1_Four_Colors` | Editable `ShortGrass_Fluffy_v1_SoftYellow`, `_DustyPink`, `_Lavender`, `_SageGreen` |
| `02_FluffyGrass_Demonstration_Patch` | 32 linked, rotated/scaled tufts |
| `03_Existing_GrassBlock_Linked_Copies` | Ten new platform objects sharing the unchanged approved V3 block mesh/materials |
| `04_Review_Cameras_And_Labels` | Low/elevated/detail/opposite cameras and variant labels |

The four masters are at X8.2/9.4/10.6/11.8, Y−11, Z1. The 3×2 block patch is centred near X10, Y−8, with tufts placed at the actual Z1 block surface. The saved viewport frames this group. Select a master and use numpad decimal to frame it; turn overlays on when editing.

Viewport lighting matches the inspected live Mobs library: Material Preview, `forest.exr`, intensity1.0, scene lights/world off, overlays/shadows/cavity off. Existing scene lighting and camera remain unchanged. The `*_Existing_Lighting.png` previews test that original lighting; the Godot previews are a separate neutral validation fixture, not a claim of identical renderer output.

## Design and reference

Inspected the user-supplied `/Users/tin/Desktop/Game Dev/local_references/Os' Colorful Grasses (Tall).zip`; the alternate `_local_references/Os_Colorful_Grasses_Tall.zip` does not exist here. Its four short-grass images are16×16 binary-alpha sprites with54.3% opaque pixels, selected equally by `short_grass.json`. `os_tinted_cross.json` has two central45° crossing cards plus four22.5° tilted cards, upward shading and biome tint index0. The grayscale lower pixels require Minecraft tinting.

The candidate uses **new procedurally authored16×16 silhouettes**, ten unequal stepped blades plus short interleaved root leaves, with46.5% tile coverage. No reference texture pixels are shipped. Its independent six-card arrangement combines two asymmetric central cards and four shorter outward-fanning cards. Tip accents are soft yellow, dusty pink, lavender and sage; all variants share ground-matched green roots sampled from the existing approved `grass_top_0` palette. The six layers provide density while preserving transparent pixel gaps.

## Asset contract

| Per tuft | Value |
|---|---:|
| Cards / quad strips | 6 /12 |
| Triangles / vertices | 24 /36 |
| Local footprint | Approximately .476×.474m |
| Top above origin / root penetration | .388m / .012m |
| Meshes / surfaces / shared materials | 1 /1 /1 |
| Shared texture | One128×32RGBA PNG; four16×16 tiles,8px gutters |
| Filtering / alpha | Nearest with nearest mipmaps / binary cutout.5 |

One block is1m. Native Blender Z-up exports once to Godot Y-up. Each GLB has identity transform and bottom-centred placement origin, one embedded atlas, one double-sided MASK material, no rig, collision, camera, light or animation. Each GLB is approximately5KB. The four meshes differ only in atlas UV region.

Source `UV_Atlas` is texture mapping. **UV2.x** stores squared normalized sway height: roots0, middle.1764, tips1. **UV2.y** stores cardID/5; glTF flips V, so decode cardID as `(1-UV2.y)*5`. Native vertex groups `Wind_Anchors`/`Wind_Sway` also retain editable weights. No wind system is installed. Do not lightmap-unwrap over UV2.

Blender uses cutout diffuse/transmitted thin-leaf lighting with no emission and disables grass shadow casting to avoid stacked dark roots. It does not add contact disks or modify ground textures. Roots penetrate the surface; color and upward shading create the transition.

## Files and Godot use

- `ShortGrass_Fluffy_v1.blend` is an origin-centred **appendable asset library** containing the four objects and dependencies. Open the central environment scene for visual review; use File → Append to reuse the library objects.
- `exports/ShortGrass_Fluffy_v1_{SoftYellow,DustyPink,Lavender,SageGreen}.glb` are portable standard-PBR fallback exports.
- Copy this package into a Godot project, retaining its relative paths. Use the matching **`ShortGrass_Fluffy_v1_*.tscn`** to obtain the intended appearance: each wrapper uses `ShortGrass_Fluffy_v1_Setup.gd`, shared `ShortGrass_Fluffy_v1_Material.tres`, atlas and static foliage shader. The shader lights both faces upward without emission; setup disables card shadows. Bare GLBs alone cannot reproduce this thin-foliage lighting under every light direction.
- `previews/` contains low/elevated and opposing close views. `Original_Texture_Board.png` shows the original palette tiles.
- `manifest.json`, `glb_validation.json`, `godot_validation.json` and `preservation_validation.json` record measurements and checks.

Verified real Godot4.7.2 Metal Mobile import/render on Apple M2Pro in an isolated fixture: four GLBs, alpha scissor.5, double-sided nearest materials, identity origins, Y-up dimensions,36vertices/24triangles, zero root sway weights, wrapper material/shadow setup and rendered pixels. Main project/map settings and gameplay are untouched.

Backup and source audits: `.validation/short_grass_fluffy_v1/before_dungeons_ground_style_v2.blend`, original SHA256, saved-source SHA256 and before/after datablock fingerprints. Independent read-only review found no blockers; final fresh-open preservation audit is included separately.

Limitations: pending human artistic review; no phone performance measurement, wind, collision or distance LOD.500tufts total12,000triangles, but six-card alpha overdraw and instance draw calls still need device profiling. Future integration should batch the four variant meshes with shared material, typically four MultiMeshes, and choose density/distance limits on the target phone. Existing gameplay assets are not replaced.
