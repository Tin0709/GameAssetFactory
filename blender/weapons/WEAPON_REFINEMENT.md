# Weapon readability refinement

Current revisions: Blocky Pistol V3, M4A1 V4, Blocky Shotgun V3. Created through Blender MCP; earlier working versions remain preserved.

The pistol grip now has upright parallel front/back faces, a flat stable heel, and a short integrated shoulder at the frame. Its old slanted strap and shaped toe were removed. Overall weapon bounds are unchanged: 0.273 m long, 0.052 m wide and 0.227 m high. The M4A1 and shotgun guards are widened locally from approximately 31 mm to 36 mm for isometric readability, retaining their continuous welded connections and unchanged overall bounds.

| Asset | Tris before / after | Blender | GLB | Side | Isometric | Trigger close-up |
|---|---:|---|---|---|---|---|
| Pistol | 352 / 340 | [Blend](pistol/blocky_pistol_v3.blend) | [GLB](pistol/blocky_pistol_v3.glb) | [Side](pistol/blocky_pistol_v3_side.png) | [Isometric](pistol/blocky_pistol_v3_isometric.png) | [Close-up](pistol/blocky_pistol_v3_trigger_closeup.png) |
| M4A1 | 760 / 760 | [Blend](m4a1_blocky/m4a1_blocky_v4.blend) | [GLB](m4a1_blocky/m4a1_blocky_v4.glb) | [Side](m4a1_blocky/m4a1_blocky_v4_side.png) | [Isometric](m4a1_blocky/m4a1_blocky_v4_isometric.png) | [Close-up](m4a1_blocky/m4a1_blocky_v4_trigger_closeup.png) |
| Shotgun | 670 / 670 | [Blend](shotgun/blocky_shotgun_v3.blend) | [GLB](shotgun/blocky_shotgun_v3.glb) | [Side](shotgun/blocky_shotgun_v3_side.png) | [Isometric](shotgun/blocky_shotgun_v3_isometric.png) | [Close-up](shotgun/blocky_shotgun_v3_trigger_closeup.png) |

[True-scale comparison](weapon_refinement_comparison.png) / [Comparison Blender scene](weapon_refinement_comparison.blend).

Each static body is a single connected manifold mesh; there are no loose vertices, duplicate indexed faces, boundary edges or inconsistent face winding. Shotgun_Pump stays separately animatable and manifold, with its guide-tube clearance and pivot retained.

Materials and the packed 64x64 atlas are unchanged, including the charcoal/cool-gray/cyan palette, mild specular response, nearest sampling and subtle edge highlights. Root and all attachment-marker matrices exactly match the preceding revisions. Identity scale, applied rotations and grip-centered origins remain. Blender +Y forward converts to Godot -Z forward. Runtime object names and folder structure remain consistent.

GLB validation confirms exported triangle counts, bounds, markers, one material and one embedded image per asset. Pistol and M4A1 each use one runtime surface; shotgun has two for its movable pump. Godot gameplay files were not modified. All side/isometric/close-up previews are transparent RGBA.

Measured results: weapon_refinement_report.json, weapon_refinement_preservation.json, weapon_refinement_glb_validation.json. Source: refine_weapon_readability.py, which reuses the preserved construction source and structural cleanup to replace only the requested grip and guard geometry.
