# Cuboid player v1

Original survivor with a sharp cube head, ochre field jacket, cropped dark hair, charcoal trousers, chunky brown boots, and a single cyan chest patch. Built from scratch through Blender MCP, separately from all previous players.

- `player_cuboid_v1.blend`: one character mesh `Player_Cuboid_Base`, rig `Player_Cuboid_Rig`, and separate preview studio collection.
- 276 triangles, 184 vertices, 23 disconnected cuboids, one material.
- `player_cuboid_atlas_64.png`: 64×64 sRGB atlas, nearest sampling, padded tiles. Texture is also packed into the blend. Matching surfaces deliberately share UV regions.
- `player_cuboid_v1_preview.png`: 1000×1000 transparent RGBA preview.
- 18 bones: root; hips, spine, chest, neck, head; bilateral upper arm, forearm, hand, thigh, shin, foot chains.
- Rigid skinning: one bone and weight 1.0 per vertex. No bevels, smooth shading, or animation data.
- Height 1.82 m, Z up, forward -Y, ground at Z=0. Left is character-left (+X). Object transforms are identity.

Suitable for later FK idle, walk, and run animation. Root handles travel; hips/spine/chest/neck/head provide secondary motion; elbow and knee segmentation permits smooth joint rotation while retaining crisp boxes. Deep bends may expose small seams, expected for rigid articulation. Pose checks preserved every edge length to within 0.000001 m, then reset all bones. No animations were created.

Compared with the previous beveled sage player, this character uses strict rectangular solids, rigid segmented limbs, a new ochre outfit, pixel-painted details, and a single atlas material. `asset_report.json` records metrics and validation. Build and validation Python recipes are included for inspection.
