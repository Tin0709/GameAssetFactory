# Exact classic cuboid player v3

1 model unit = 0.05625 m. Character height is 32 units = 1.80 m. Geometry dimensions were measured after reopening the saved file and verified to within 0.000001 m.

| Part | Model units: width × depth × height | Meters: width × depth × height | Z range (m) |
|---|---|---|---|
| Head | 8 × 8 × 8 | 0.450 × 0.450 × 0.450 | 1.350–1.800 |
| Torso | 8 × 4 × 12 | 0.450 × 0.225 × 0.675 | 0.675–1.350 |
| Each classic arm | 4 × 4 × 12 | 0.225 × 0.225 × 0.675 | 0.675–1.350 |
| Each leg | 4 × 4 × 12 | 0.225 × 0.225 × 0.675 | 0–0.675 |

Overall rest bounds: width 0.900 m (16 units), depth 0.450 m (8 units, set by head), height 1.800 m (32 units). Head X/Y spans ±0.225 m. Torso X spans ±0.225 m and Y spans ±0.1125 m. Arms occupy X -0.450 to -0.225 m and +0.225 to +0.450 m. Legs occupy X -0.225 to 0 m and 0 to +0.225 m. Arms and legs both have Y spans ±0.1125 m. Feet rest at Z=0.

The original survivor atlas uses dark hair, muted teal clothing, dark pants, brown footwear and a small cyan chest pixel. 64×64 sRGB PNG, nearest sampling, one packed material, roughness 0.58, specular IOR level 0.22, metallic 0. No outer clothing layers, bevels, separate hands, or shoe geometry alter the silhouette.

Mesh: `Player_Cuboid_Base`. Rig: `Player_Cuboid_Rig`. 120 triangles, 80 vertices, 18 bones. Head and torso are single cuboids; each arm and leg comprises two flush 6-unit-high cuboids, permitting rigid elbow/knee motion without changing the exact 12-unit rest silhouette. Hand and foot bones provide attachment pivots without separate geometry. All vertices carry one bone influence at weight 1.0. Pose checks preserve section edge lengths. Saved in neutral rest pose; no animation actions.

Transparent 1000×1000 previews: `player_cuboid_v3_front.png`, `player_cuboid_v3_isometric.png`, `player_cuboid_v3_side.png`. `asset_report_v3.json` contains measured dimensions and validation. Earlier versions were verified unchanged.
