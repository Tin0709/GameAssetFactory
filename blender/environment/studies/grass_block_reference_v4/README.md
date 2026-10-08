# Square-ended meadow grass v4

Original Blender-authored study based on the user's requested blunt grass silhouette and meadow palette. No reference geometry or texture pixels are copied. Open `grass_block_reference_v4.blend`, scene `ENV_Grass_Block_Reference_V4`. The grass mesh is selected; hero and close-up cameras, warm/cool lights and an editable node material are included.

The patch has 36 zero-thickness, constant-width flat leaves on a jittered 6 × 6 root grid. Heights range from 0.2821–0.4795 m, widths from 0.12035–0.19923 m. Every leaf has a substantial flat horizontal top edge of exactly the same width as its base, four rings at 0, 0.22, 0.65 and 1 of its height, and three quads. Total: 288 authored vertices, 108 quads, 216 triangles. Varied angle, height, width and slight planar lean give an interwoven silhouette. Edge-on leaves can look thin from a specific camera, but no leaf tapers to a point.

The block remains exactly 1 × 1 × 1 m, with original XY coordinates, face topology, corners and UV layout. The user's subsequent request to thicken the green cap by 15% is represented in actual mesh boundary positions: stepped depths of 0.125 / 0.1875 / 0.25 m become 0.14375 / 0.215625 / 0.2875 m. Shared green/dirt boundary vertices move together, so the surfaces remain connected. The export copy uses the established E1 collinear top/bottom rim simplification and remains 288 triangles.

The packed opaque atlas is 128 × 128 pixels with nearest sampling. Blade tones range from RGB (52,105,57) to (132,171,92); top base is (91,135,66), dirt base (130,103,64). Small sparse irregular flecks replace the previous aligned diamond dots. Source reference swatches and their top-left image coordinates are recorded in `export_manifest_v4.json`; these inform original colors rather than being pasted into a texture. Vertex bend colors are data and are deliberately not linked to Blender albedo.

`GRASS_BEND_DATA` is POINT/FLOAT_COLOR: R = t², G = t, B = blade height / 0.48 m, A = 1. Roots have exactly zero R/G. `UV_Blade_Root` is the second map: (root X + 0.5, root Y + 0.5). Blender's glTF V flip and Y-up conversion yield Godot local root XZ = UV2 − 0.5. Grass is displayed at Blender Z = 1 but exported at location zero, with local roots at Z = 0. The validator checks actual GLB POSITION, COLOR_0 and TEXCOORD_1 values against the authored rest mesh.

The saved Blender file has a quiet four-second wind loop at 24 fps, frames 1–96; frame 97 closes the seam and is excluded. Preview tip amplitudes are 0.018 m X and 0.008 m Y, with slight height delay. Four shape keys have frame-driven sine/cosine values and preserve roots exactly. Grass ray cast shadows are disabled (`visible_shadow=False`); the block still shades normally. Runtime stronger wind and player interaction are owned by the Godot shader, not this quiet inspection animation.

Exports in `game_mobile_3d/assets/environment/grassland/`: `grass_patch_v4.glb`, `grass_dirt_block_v4.glb`, `environment_atlas_v4.png`, `export_manifest_v4.json`. GLBs contain rest-only meshes with no morph targets, animations or skins. V3 study SHA-256 is `f1243780e7197d6b3495a43e9e19a145f5e4693bec08c8c502611ba1a2cc20be`; the builder and validator check it and all four archived v3 export hashes.

Reproduce from the repository root with Blender 5.2:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python blender/environment/studies/grass_block_reference_v4/build_asset.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python blender/environment/studies/grass_block_reference_v4/validate_asset.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python blender/environment/studies/grass_block_reference_v4/render_previews.py
```

Validation was written and observed failing for the missing v4 file before creation. Fresh saved-file and GLB validation passes, including tip widths, planarity, four rings, masks, UV2, opaque packed nearest atlas, cap depth multiplier, dimensions, anchored roots and wind seam. `validation_report.json` records measurements. `preview_hero.png`, `preview_detail.png` and `preview_wind_phase.png` are actual Cycles CPU renders from the saved file and have been visually inspected. The build prints a nonfatal Blender thumbnail cache permission message on this sandboxed host; saved file and exports are independently reopened and verified.

## Bare dirt extension

The user's further request adds a separate `ENV_Dirt_Block_1m_V4` object in scene `ENV_Dirt_Block_Reference_V4` and `dirt_block_v4.glb` in the same export folder. This exact flat 1m cube uses eight authored vertices, six quads and twelve triangles, with no grass cap or foliage. Local bottom Z=0 and top Z=1 become Godot Y=0/Y=1. Original warm ochre top RGB (162,130,77), deeper brown-gold sides (133,101,58) and bottom (117,88,52) use quiet sparse irregular chunky mottles. The user's crop samples and their coordinates are recorded under `bare_dirt_family` in the manifest.

The bare dirt atlas tiles use previously unused Blender pixel rows 104–127 only: top X=4–35, sides X=44–75, bottom X=84–115. All other atlas pixels remain exactly unchanged, including prior grass/blade/cap/dirt regions; existing v4 grass and grass-block GLB bytes are hash-preserved. The new GLB embeds the extended atlas and uses the same opaque nearest material. Scene `ENV_Grass_Dirt_Pair_V4` compares both blocks under the same warm key/cool fill. The main grass scene still contains only its original grass/block preview objects.

After `build_asset.py`, run the extension and its independent validator (which also reruns the complete grass validation):

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python blender/environment/studies/grass_block_reference_v4/add_dirt_asset.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python blender/environment/studies/grass_block_reference_v4/validate_dirt_asset.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python blender/environment/studies/grass_block_reference_v4/render_dirt_previews.py
```

`validate_dirt_asset.py` was observed failing for missing `dirt_block_v4.glb` before implementation, then passing after reloading the saved study and binary export. `dirt_validation_report.json` records dimensions, triangles, bare geometry and preservation checks. Actual Blender renders: `preview_dirt.png` and `preview_grass_dirt_pair.png`.
