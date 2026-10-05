# Blocky Shotgun V4

Original traditional-stock pump shotgun, inspired by the reference's long simple silhouette. The exact reference mesh, proportions, texture and colors were not copied. Only the shotgun was changed. Earlier revisions and the remaining weapon set are preserved.

## Shape and finish

Longer faceted barrel, slimmer receiver and tubular guide section. The former vertical pistol-grip stock has become a tapered traditional buttstock/wrist. A clean connected trigger frame remains below the receiver. Slate stock and pump surfaces reinterpret the visual role of wooden sections using the existing palette. Cool-gray receiver, charcoal butt pad and small cyan badge keep the shared family identity. Tiny single-segment chamfers and atlas edge accents preserve the polished block look.

The exact existing packed 64x64 atlas and material were reused: nearest sampling, roughness 0.48, metallic 0 and mild specular. No new texture or material was added.

V3 -> V4 dimensions: length 0.975 -> 1.120 m, width 0.129 -> 0.095 m, height 0.2974 -> 0.240 m. Triangles 670 -> 508 (428 body + 80 pump). One material, two runtime surfaces. One connected manifold shell per object, with zero loose vertices, boundary/non-manifold edges, duplicate indexed faces or inconsistent winding.

## Outputs

- [Blender V4](blocky_shotgun_v4.blend)
- [Godot-ready GLB](blocky_shotgun_v4.glb)
- [Side](blocky_shotgun_v4_side.png)
- [Isometric](blocky_shotgun_v4_isometric.png)
- [Front three-quarter](blocky_shotgun_v4_threequarter.png)
- [Trigger/stock-wrist close-up](blocky_shotgun_v4_trigger_closeup.png)

## Runtime attachment notes

Object names remain Blocky_Shotgun_Root, Blocky_Shotgun_Base and Shotgun_Pump. The grip-centered root and Grip_Point stay at (0,0,0). Unit scale, applied rotation, Blender +Y forward / +Z up and Godot -Z forward / +Y up remain unchanged. The pump is a separate named rigid object, centered at the support hand with a clearance bore around the guide tube. No pump animation was created; check receiver clearance when setting its future stroke.

Muzzle_Point and Support_Hand_Point names and roles are preserved. Their locations were updated to fit the new silhouette:

| Marker | Blender (x,y,z) m | Godot (x,y,z) m |
|---|---|---|
| Grip_Point | (0,0,0) | (0,0,0) |
| Support_Hand_Point | (0,0.356,0.070) | (0,0.070,-0.356) |
| Muzzle_Point | (0,0.690,0.122) | (0,0.122,-0.690) |

Existing attachment code can keep using these names. Hand support and muzzle effects should use the nodes rather than hard-coded offsets. GLB bounds, triangle counts, names, material count, embedded image and nearest sampler were verified; studio objects are excluded. This delivery does not change the gameplay project.

Source: rebuild_shotgun_v4.py. Reports: blocky_shotgun_v4_report.json and shotgun_v4_glb_validation.json. PNG previews have transparent RGBA backgrounds.
