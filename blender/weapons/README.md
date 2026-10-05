# Blocky weapon family

Latest geometry-clean revisions: [Pistol V2, M4A1 V3 and Shotgun V2](GEOMETRY_CLEANUP.md). That report links the current GLBs, trigger close-ups and isometric previews. The original family versions below remain preserved.

Created and validated with Blender MCP. M4A1 V2 is the style anchor; V1 remains intact. The pistol and pump-action shotgun are original designs with no commercial logos or copied markings.

[Shared weapon style guide](WEAPON_STYLE_GUIDE.md)

## Assets

| Weapon | Length x width x height (m) | Tris | Meshes | Blender | Godot GLB |
|---|---|---:|---:|---|---|
| M4A1 | 0.9970 x 0.1030 x 0.4505 | 552 | 1 | [Blend](m4a1_blocky/m4a1_blocky_v2.blend) | [GLB](m4a1_blocky/m4a1_blocky_v2.glb) |
| Pistol | 0.2730 x 0.0520 x 0.2270 | 264 | 1 | [Blend](pistol/blocky_pistol_v1.blend) | [GLB](pistol/blocky_pistol_v1.glb) |
| Shotgun | 0.9750 x 0.1290 x 0.2974 | 424 | 2 | [Blend](shotgun/blocky_shotgun_v1.blend) | [GLB](shotgun/blocky_shotgun_v1.glb) |

M4A1 width reduction: 11.2069%; only vertex X coordinates changed. Length, height, UVs, materials and attachment points are unchanged.

## Presentation

[True-scale comparison](weapon_family_comparison.png) / [Comparison Blender scene](weapon_family_comparison.blend). The orthographic comparison uses meter-scale geometry without individual weapon scaling.

| Weapon | Side | Front three-quarter | Isometric |
|---|---|---|---|
| M4A1 | [Side](m4a1_blocky/m4a1_blocky_v2_side.png) | [Three-quarter](m4a1_blocky/m4a1_blocky_v2_threequarter.png) | [Isometric](m4a1_blocky/m4a1_blocky_v2_isometric.png) |
| Pistol | [Side](pistol/blocky_pistol_v1_side.png) | [Three-quarter](pistol/blocky_pistol_v1_threequarter.png) | [Isometric](pistol/blocky_pistol_v1_isometric.png) |
| Shotgun | [Side](shotgun/blocky_shotgun_v1_side.png) | [Three-quarter](shotgun/blocky_shotgun_v1_threequarter.png) | [Isometric](shotgun/blocky_shotgun_v1_isometric.png) |

## Materials and geometry

Each asset has one opaque material and a packed 64x64 atlas. The new weapons reuse the original M4A1 atlas palette and motifs to maintain family consistency. GLBs embed the image and export nearest-neighbor/nearest-mipmap filtering. Metallic 0, roughness 0.48, mild Blender specular 0.25. Subtle painted edges plus small single-segment structural chamfers provide highlights; no outline shader is required. GLTF core specular response can differ slightly from Blender.

M4A1 and pistol: one mesh and one draw surface each. Shotgun: main mesh plus Shotgun_Pump, two surfaces using the same material. The pump pivot is at the support-hand position, with unit scale and zero rotation. Move it approximately 0.045 m rearward along Blender local Y (Godot local +Z) for later pump animation. No reload or pump animations were created.

## Godot attachment convention

Root and main mesh origins sit at the primary hand grip. Blender +Y forward / +Z up maps to Godot -Z forward / +Y up. All roots and main meshes have identity transforms. The pump has an intentional local translation at its working center. Grip_Point is (0,0,0) on every asset. Keep all marker nodes when importing. Instance under a hand BoneAttachment3D or weapon socket; align socket rotation to the hand bone. This delivery does not modify the Godot gameplay project.

| Weapon | Godot Muzzle_Point (x,y,z) m | Godot Support_Hand_Point (x,y,z) m |
|---|---|---|
| M4A1 | (0.000, 0.180, -0.686) | (0.000, 0.125, -0.375) |
| Pistol | (0.000, 0.117, -0.236) | (0.000, 0.000, -0.034) |
| Shotgun | (0.000, 0.202, -0.650) | (0.000, 0.131, -0.356) |

Use Muzzle_Point.global_position for projectile/VFX placement and -Muzzle_Point.global_basis.z.normalized() for forward direction.

## Validation and source

Blender validation confirms dimensions, triangle counts, unit scale, zero rotation, UV bounds, nondegenerate triangles, packed atlas, nearest filtering, and centered grips. GLB validation confirms matching bounds/counts, one material each, exported marker positions/axes, embedded image, nearest sampler and no animations. Preview PNGs are 1280x960 RGBA; comparison is 2048x768 RGBA. All contain transparent pixels.

Source: build_weapon_family_v1.py and build_weapon_comparison.py. Checks: validate_weapon_family_blender.py / validate_weapon_family_glb.py; machine-readable results in weapon_family_report.json, blender_validation.json and glb_validation.json. The builder guards against overwriting existing family outputs and opens the original M4A1 read-only. Run it via Blender MCP in an isolated Blender process.

