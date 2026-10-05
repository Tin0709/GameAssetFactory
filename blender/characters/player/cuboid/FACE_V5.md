# Face-only correction v5

Only eight texels changed, all inside the lower four rows of the existing 8×8 front-face region. All hair texels and every texel outside this face region remain identical to v4.

Facial centerline is X=3.5 in zero-based face coordinates. Eyes share row 4: whites at X=1 and 6, pupils at X=2 and 5. Pupil spacing increased from 2 to 3 model units, with matching mirrored eyes. Nose occupies centered columns 3 and 4 on row 5; the neutral mouth occupies those same columns on row 6. The one-sided cheek highlight was removed. Nose and mouth use existing palette colors for a soft, calm expression.

The 64×64 atlas remains packed, with nearest sampling and one unchanged material shader. Geometry, proportions, rig, bone transforms, weights, UVs, clothing, and hair were verified unchanged after reopening the new file. V4 remains unchanged. No animation was added.

Outputs: `player_cuboid_v5.blend`, `player_cuboid_v5_atlas_64.png`, and transparent 1000×1000 `player_cuboid_v5_front.png`, `player_cuboid_v5_isometric.png`, `player_cuboid_v5_side.png`. `asset_report_v5.json` lists the exact changed texel coordinates and verification results.
