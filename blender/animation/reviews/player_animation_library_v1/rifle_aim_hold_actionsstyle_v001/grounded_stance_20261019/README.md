# Rifle Aim / Hold — modest grounded stance, Pending

Same `Rifle_Aim_Hold_ActionsStyle_v001` in the existing `Animation_Showcase.blend`. This is the user's requested lower-body refinement, still awaiting visual review. No extra Action or Showcase was added.

Compared with the previous arm-axis-aligned pose, both rigid legs now open slightly into a planted aiming stance: 0.32 m lateral sole-center spacing, 0.10 m fore/aft stagger in the stance frame, 3° outward leg tilt and 5° toe-out per side. A 6.9° stance blade follows the existing body direction. This is deliberately narrower than the user's example. Feet remain fixed throughout breathing; the original Hips motion continues above them. Legs remain single rigid blocks, without knees or ankles; the tilted cuboid soles rest on their lowest corners.

Only the 12 location/Euler channels on `Leg.L` and `Leg.R` changed. All 114 other curves are exact copies: torso/head, arms, rifle, hand contacts, barrel/right-arm alignment, scales and 0.9/1.8/3.6 s idle clocks. The stance is an authored adaptation to the user's rifle reference, not a newly discovered Actions & Stuff crossbow stance. The literal crossbow study remains unchanged.

- In the Animation Library select `Rifle_Aim_Hold_ActionsStyle_v001` (Pending), then Play. 30 FPS, F1–108; F109 is the excluded closing key; 3.6 s loop.
- `comparison_stance.png`: same-camera before/after front and three-quarter poses, F85.
- `aim_reference_30fps_1x.mp4`: two continuous cycles at original speed / 30 FPS. Front, side and three-quarter stills are included.
- The complete preceding Action remains in the unchanged source identified by `previous_pending_source` in `entry.json`; complete canonical/native pre-edit backups also remain outside the repository. All approved Actions and Godot remain intact.

Rebuild with Blender opening `authoring/baseline_entry.json`'s source, then `--python authoring/build.py`; output is written beside the script. Validate by opening this candidate and running `authoring/validate.py`. Baseline evaluated matrices are regenerated in memory from the preserved preceding source, rather than committing a generated transform dump. Render with `authoring/render.py -- reference`.

Research-only/nonproduction, Blender review only. No Godot animation, scene, controller, camera or approved gameplay change.

Validated217half-frame poses: zero unintended intersections, no hip gaps, exact loop pose; maximum sole-vertex drift 0.24µm and non-leg matrix difference 0.0. Saved/reopened selectors and two native playback loops pass;30FPS movie decodes216frames. All88 other Actions and6884prior protected files, including2007Godot files, remain exact.
