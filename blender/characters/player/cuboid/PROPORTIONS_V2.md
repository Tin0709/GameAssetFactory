# Valorie reference revision

Saved as `player_cuboid_v2.blend`; v1 is preserved. Only the cuboid player's source, model, and reference image were inspected for this revision. The reference is a single posed three-quarter image, so proportions are visually matched rather than reconstructed from measured orthographic views.

| Proportion | v1 | v2 | Change |
|---|---:|---:|---|
| Overall height | 1.82 m | 2.05 m | 13% taller |
| Cube head | 0.44 m | 0.42 m | 24% → 20.5% of total height |
| Torso width | 0.47 m | 0.37 m | 21% narrower; head now wider than torso |
| Torso depth | 0.29 m | 0.205 m | 29% flatter |
| Torso height | 0.48 m | 0.598 m | 25% longer |
| Outer shoulder width | 0.92 m | 0.718 m | 22% narrower |
| Arm width | 0.212 m | 0.166 m | 22% slimmer |
| Shoulder-to-hand length | 0.709 m | 0.791 m | 12% longer |
| Leg height to hip seam | 0.746 m | 0.918 m | 23% longer |
| Leg width | 0.209 m | 0.176 m | 16% slimmer |
| Boot width/depth | 0.233 / 0.378 m | 0.176 / 0.250 m | Reduced bulky feet |

Both torso sections have exactly the same flat front plane (Y = -0.1025 m); clothing details are painted into the atlas, without belly or pocket protrusions. Thighs, knees, calves, and boot shafts share a constant 0.176 m width and 0.205 m depth. Boots keep only a small toe extension.

The outfit now follows Valorie's red hair, headband, green eyes, dark teal tunic, brown belt/gloves/boots, and pale sleeve/knee panels, with a small cyan chest accent retained. All parts remain sharp cuboids.

Rig pivots were repositioned to the new proportions. `Player_Cuboid_Rig` retains 18 bones and rigid weights, suitable for later idle/walk/run. Two final pose checks preserved box dimensions; the saved model is in its neutral rest pose with no animations. 276 triangles, one material, one packed 64×64 pixel atlas.

`player_cuboid_v2_preview.png` is the transparent three-quarter render. `player_cuboid_v2_comparison.png` shows v1 and v2 from front and side at identical orthographic scale and ground height.
