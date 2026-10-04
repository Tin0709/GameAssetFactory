# Player_Idle

Open `player_voxel_v2_idle.blend` and play the timeline. The active action is `Player_Idle`. The source `../player_voxel_v2.blend` remains unchanged.

- Playback: frames **1–48**, **24 FPS**, **2 seconds**.
- Frame **49** is the duplicate closure of frame 1. It supplies the correct final interpolation segment; do not hold/render this duplicate as an extra frame.
- Eight authored poses at 1, 7, 13, 19, 25, 31, 37, 43, plus closure 49. Smooth cubic Bezier curves with matched seam tangents and Cycles modifiers.
- 60 scalar curves / 540 scalar keys; 19 bones animated. No per-frame bake, constraints, drivers or added bones.

## Motion and poses

1: centered, inhalation lift, alert head and lightly flexed elbows.
7: easing toward the right-side weight shift; shoulders follow the torso.
13: rightward weight-shift peak with relaxed arm follow-through.
19: settling toward center as the chest exhales.
25: centered exhalation low point; shoulders and hands still settling.
31: easing into the opposite weight shift and beginning the next inhale.
37: leftward weight-shift peak; head and arms counterbalance gently.
43: recovering toward the first pose with delayed hand motion.
49: exact closure of pose 1, including curve slopes.

Hip travel is ±6 mm laterally, with a small vertical breathing offset. The slightly lowered alert stance gives the knees room to compensate while the boots remain planted. Spine/chest motion leads the clavicles, then upper arms, forearms and hands. Different left/right delays and amplitudes break mechanical symmetry.

Animated bones: Hips (location/rotation); Spine, Chest, Neck, Head; Clavicle.L/R, UpperArm.L/R, Forearm.L/R, Hand.L/R; Thigh.L/R, Shin.L/R, Foot.L/R (rotations). Root has no channels and stays stationary. The rig object remains at the origin.

Leg compensation was calculated offline using a two-bone solve and stored as ordinary FK rotation keys. Existing hierarchy, bind matrices, bone names, locks and rotation modes were preserved. No runtime IK is needed. This action does not alter the rest pose: choose Armature > Rest Position to inspect the original bind pose, then return to Pose Position for playback.

## Validation

All 48 frames were rendered and the key-pose sheet was inspected for shoulder/elbow artifacts. Normal-speed timing was verified as a two-second loop; frame-by-frame motion and periodic tangents were checked numerically. The seam has no pose or velocity jump. No weight or geometry corrections were required.

- 193 quarter-frame samples over frames 1–49.
- Maximum sole drift: **0.000881 mm**, negligible floating-point/interpolation error.
- Root transform error and rig-object translation: **zero**.
- Frame 1 vs 49 evaluated vertex difference: **zero**.
- Seam tangent error: approximately **1.06e-10**.
- Largest vertex step at 24 FPS: **2.73 mm**; seam step **1.60 mm**.
- Mesh coordinates/topology/weights, material data, rest bones and rig settings match the captured source signature.
- Source `.blend` SHA-256 before/after: `6128E3A2738E96E9CC376CEF6228430E7D4D3DD633E6FDA05FE6DFFE9DFC9BC6`.

`idle_validation.json` contains measurements. Production engine import and actual mobile playback have not been tested.

## Previews and scripts

- `Player_Idle.gif`: looping 512px preview on a dark background, 48 frames / 2 seconds. GIF timing uses alternating 40/50 ms delays because the format has 10 ms time resolution.
- `Player_Idle.apng`: transparent animated preview with 24 FPS timing.
- `Player_Idle_preview.png`: transparent 1024px still.
- `idle_pose_sheet.jpg`: eight key poses.
- `frames/`: rendered 512px RGBA source frames.
- `create_idle.py`: MCP authoring recipe; refuses to overwrite an existing `Player_Idle` action.
- `validate_idle.py`: repeatable subframe foot/loop/deformation checks.
- `package_preview.py`: assembles the rendered frames into previews.

The saved Blender file keeps the original asset preview camera/lights and 1024px render resolution, with frame 1 active and timeline playback at 24 FPS. No other actions were overwritten.
