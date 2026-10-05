# Pistol V4 grip refinement

Original compact grip refinement, inspired only by the reference's clean chunky silhouette. The reference's colors, accessories and geometry were not copied. Only the pistol was revised; prior revisions and the M4A1/shotgun remain unchanged.

The rear projecting shoulder is removed. The handle is a simple four-corner block with a small controlled rake, flat bottom and an integrated upper frame joint. The trigger guard remains welded at both ends. Slide, sights, muzzle, material/atlas, cyan accent and attachment matrices retain their previous design.

Overall dimensions: 0.260 m length x 0.052 m width x 0.227 m height. Length reduced by 13 mm only because the unwanted rear extension is gone; slide dimensions, height and width are unchanged. Triangle count: 340 -> 296. One connected manifold mesh, one material and the same packed 64x64 atlas. Zero loose vertices, boundary/non-manifold edges, duplicate indexed faces or inconsistent face winding. Normal recalculation and applied unions retain rigid low-poly geometry.

- [Blender V4](blocky_pistol_v4.blend)
- [Godot GLB](blocky_pistol_v4.glb)
- [Side preview](blocky_pistol_v4_side.png)
- [Isometric preview](blocky_pistol_v4_isometric.png)
- [Trigger/grip close-up](blocky_pistol_v4_trigger_closeup.png)

Root and mesh names are preserved. Grip_Point, Support_Hand_Point and Muzzle_Point have unchanged full local transforms. Grip origin remains (0,0,0); Blender +Y forward / +Z up maps to Godot -Z forward / +Y up. The GLB embeds the atlas, uses nearest sampling, has one surface/material, matching dimensions and verified marker coordinates. No animation was created and no gameplay project files were edited.

Validation: blocky_pistol_v4_cleanup_report.json, pistol_v4_glb_validation.json and pistol_v4_preservation.json. Source: refine_pistol_grip_v4.py, reusing the retained structural construction helpers.
