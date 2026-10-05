# M4A1-inspired block rifle V1

Original game prop: compact top rail, solid angled stock, three broad handguard vents, forward-canted magazine, and cyan receiver badge. No copied texture, branding, labels, or decorative text. All dimensions and geometry were authored for this asset.

## Deliverables

- `m4a1_blocky_v1.blend`: asset plus isolated preview studio.
- `m4a1_blocky_v1.glb`: runtime mesh, root and attachment markers; no studio.
- `m4a1_blocky_atlas_64.png`: original 64x64 RGBA atlas, also packed into Blender.
- `m4a1_blocky_front.png`, `m4a1_blocky_side.png`, `m4a1_blocky_isometric.png`: 1280x960 transparent previews. Front means looking directly down the muzzle axis.
- `build_m4a1_blocky_v1.py`: source builder. Run in a separate background Blender process; it resets only that process and replaces this folder's own outputs.
- `asset_report.json`, `runtime_validation.json`, `validate_export.py`: measured geometry and GLB/alpha validation.

## Runtime structure and budget

`M4A1_Blocky_Root` contains `M4A1_Blocky_Base`, `Grip_Point`, `Muzzle_Point`, and `Support_Hand_Point`. One joined mesh with named part vertex groups for editing. 552 triangles, 324 Blender vertices, 295 polygons, one opaque material and one draw surface. UV splits increase the exported vertex count. No rig, constraints, animation, or unapplied modifiers. Parts are assembled rigid components rather than a watertight manufacturing mesh; covered Stock_Link caps are omitted.

Length 0.997 m, width 0.116 m, height 0.4505 m. Identity object transforms; mesh and root origin at primary grip center. Single-segment bevels are 1-2.5 mm on selected main parts. Pixel highlights handle the remaining edge contrast.

Material: charcoal/cool-gray with cyan badge, nearest sampling, metallic 0, roughness 0.48, Blender specular IOR level 0.25. glTF core export retains base color, metallic and roughness; its specular response may differ slightly from Blender. Nearest mip filtering is exported for minification.

## Godot integration

Import the GLB into your desired asset folder and instance it under a hand `BoneAttachment3D` or a weapon socket. Align the root at the hand grip; adjust socket rotation to the hand's local axes. Do not automatically scale it without checking the character pose. Import is not yet wired into the gameplay project.

Blender axes: +Y muzzle-forward, +Z up. glTF/Godot axes: -Z muzzle-forward, +Y up. Blender marker coordinates (meters): Grip `(0,0,0)`, Muzzle `(0,0.686,0.180)`, Support Hand `(0,0.375,0.125)`. Godot local positions: Muzzle `(0,0.180,-0.686)`; Support Hand `(0,0.125,-0.375)`.

Use `Muzzle_Point.global_position` for projectile/VFX placement and `-Muzzle_Point.global_basis.z.normalized()` for the forward direction. Keep muzzle and support marker nodes when importing. Optional off-hand placement uses Support_Hand_Point. Reload animation and firearm mechanics are intentionally future integration work.

## Validation

Blender MCP reopened the saved file and verified topology/material/image/transforms, then produced the final renders and saved the file. Binary GLB validation confirms 552 triangles, one surface/material, embedded image and nearest sampler. All previews have RGBA alpha ranging from 0 to 255. Player V6 and Zombie V2 source SHA-256 values match their pre-build values; neither was changed. Initial MCP startup failures required a background Blender build; the final connection was restored for validation and delivery renders.
