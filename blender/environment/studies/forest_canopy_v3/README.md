# Original forest canopy V3

**Reusable authored assets; awaiting user art review.** The new user gameplay reference informed broad cuboid leaf masses, smaller rectangular leaf clusters and the scale of foliage detail. No game geometry, texture or imagery is copied. The existing V2 source and GLBs remain unchanged.

V3 replaces V2's ellipsoid-derived horizontal crown terraces with four or five offset cuboid masses of different heights and dimensions. Attached leaf patches and small corner bites break their outlines; irregular rectangular vertex-color clusters add surface variation. This is an opaque geometry study, without bitmap textures, cutout cards or a custom material shader.

| Runtime asset | Triangles | Height | Mesh nodes |
|---|---:|---:|---|
| `tree_oak_a.glb` | 3,794 | 4.95 m | `Bark`, `Leaves` |
| `tree_oak_b.glb` | 3,282 | 4.35 m | `Bark`, `Leaves` |
| `shrub_leaf.glb` | 534 | 0.84 m | `Leaves` |
| `shrub_fern.glb` | 444 | 0.76 m | `Leaves` |

Runtime files: [forest_canopy_v3](../../../../game_mobile_3d/assets/environment/forest_canopy_v3/). Every mesh has one rough, opaque, single-sided material. Color inputs are sRGB palette values; Blender's `Color.color_srgb` stores their linear albedo for glTF `COLOR_0`. Keep the local `vertex_color_import.gd` hook and `.glb.import` files when reusing: the hook enables **linear vertex-color albedo** on both native Bark and Leaves materials. Godot otherwise imports a white material. Automatic generated LOD is disabled to preserve these authored leaf silhouettes; a phone LOD budget remains unverified.

`forest_canopy_v3.blend` contains the four editable asset collections and a separate diagnostic studio. Source object locations arrange that studio; mesh-local origins are bottom-centred at the trunk/root. Export occurs before the display offsets. All units are metres, with identity runtime scale/rotation. Blender Z-up converts to glTF/Godot Y-up exactly once. GLBs contain no animation, rig, lights, camera, texture or embedded collision. Add collision appropriate to the target scene.

Leaf volumes use 0.15 m cells on trees and 0.12 m cells on the boxy shrub. Hidden internal faces are culled. Same-color surface rectangles are merged, then edge endpoints are split and welded so the source has no T-junctions. The audit checks closed manifold edges both before and after triangulation, zero degenerate faces, outward orientation of every connected closed component, unit exported normals, exact bounds and linear palette values. Trunk branches, roots and fern leaves are separately closed overlapping components; their intersections are intentionally not boolean-unioned.

`manifest.json` records asset geometry and binary GLB audits. `validation_source.json` independently opens the saved source, repeats geometry/export checks and verifies V2 source/GLB hashes against the previous recorded audit. `diagnostic_v3.png` is the inspected Blender render. It diagnoses these assets only; the parent task performs native Godot import, current-main-scene integration and game-pixel review. Neither this diagnostic nor triangle counts establish phone performance or user art approval.

Rebuild from the repository root:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python 'blender/environment/studies/forest_canopy_v3/generator.py'
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python 'blender/environment/studies/forest_canopy_v3/validate_source.py'
```

Both commands use background factory startup and preserve an existing open Blender scene. Sources and outputs are restricted to the two V3 directories.
