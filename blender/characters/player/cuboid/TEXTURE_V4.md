# Original survivor skin v4

`player_cuboid_v4.blend` uses v3's exact existing mesh, 1.80 m classic proportions, UVs, weights, and 18-bone rig. Geometry and rig signatures were verified unchanged after reopening v4. V3's file hash remains unchanged. No animation was added.

The new artwork was painted from scratch as pixel color blocks. The supplied Sunny images informed the clean block-skin vibe only; neither reference was sampled or copied into the atlas.

Distinct design choices: blue field jacket with a teal shoulder yoke and pale undershirt, full dark sleeves with brown cuffs, a continuous brown utility strap and side pouch, charcoal knee-panel trousers, low brown boots, and a cyan chest marker. The hair has a stepped side crop and broad highlights; eyes and face use new pixel placement. Front, sides, shoulders, and back were checked for coherent color blocking and strap continuity. The reference's green wrap, blue overall layout, and asymmetric sleeve treatment are replaced by this jacket outfit.

One packed 64×64 sRGB atlas (`player_cuboid_v4_atlas_64.png`), nearest sampling, one material. Roughness 0.54, specular IOR level 0.22, metallic 0. Material Preview is enabled in saved 3D viewports and the atlas drives the rendered base color. 120 triangles; no new geometry.

Transparent 1000×1000 previews: `player_cuboid_v4_front.png`, `player_cuboid_v4_isometric.png`, `player_cuboid_v4_side.png`. An extra `player_cuboid_v4_back.png` documents the back-view check. `asset_report_v4.json` records the technical verification.
