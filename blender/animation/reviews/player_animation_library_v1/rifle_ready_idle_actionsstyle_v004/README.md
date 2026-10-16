# Rifle Ready Idle ActionsStyle v004 — closer arm hold

**Pending Blender review.** The user clarified with a side-view screenshot: reduce the triangle-like gap between arms and body by bringing both straight arms closer to the torso. This is a correction to the SAME v004 candidate, not a new Action. Approved v003 is unchanged. No Godot integration.

Open the existing `blender/animation/showcase/Animation_Showcase.blend` → Animation Library → `Rifle_Ready_Idle_ActionsStyle_v004`. The actual Rifle Stylized V2 remains attached. The file is left in Side view for this review. Space plays/pauses. F1–324 at30FPS/closing325 excluded;10.8second loop.

## Screenshot correction

The intact arms/rifle assembly rotates10° toward the torso around the line joining the two shoulder pivots. This makes the arms more vertical and reduces their forward reach. The rigid shoulder blocks need20mm of constant forward seating clearance relative to the chest to remain within the existing approved joint-contact envelope. This is an explicit block-rig adapter, not extra source animation.

After clearance, the left hand is77.1–78.0mm closer to the torso and the right hand45.1–45.7mm closer across the loop. Both hands also descend61–68mm relative to the previous Pending v004. The rifle follows the same10° rotation and retains its exact relationship to the right hand; the left support's existing tiny relative breathing motion is preserved. No elbow bend or forearm articulation is introduced. The correction changes the holding angle, not just its vertical height.

The earlier18mm whole-set vertical adjustment is retained. New torso, head, legs or attention timing are not authored. All their F-curves and evaluated world transforms remain unchanged from v003/v004. Existing key times, linear bake/interpolation and loop length remain exact.

## Left-support life retained

The independently authored support additive follows the inherited0.9s waist/idle bob and1.8s shoulder/head clocks:0.4–1.6mm pressure release with75ms overlap,±0.8mm tangent travel with100ms overlap, and±0.15° whole-arm rotation with125ms overlap. Actual palm motion relative to rifle is≤1.79mm. It remains the same after the tuck because the whole holding assembly is transformed together. Both blocky arms stay straight; right grip remains stable.

## Reviews

- `comparison_v004_before_after_side_30fps.mp4`: previous v004 left, corrected closer hold right, original speed/same side camera.
- `comparison_v003_left_v004_right_30fps.mp4`: approved v003 versus current corrected v004, three-quarter camera.
- `rifle_ready_idle_side_30fps_1x.mp4`, `rifle_ready_idle_three_quarter_30fps_1x.mp4`, `rifle_ready_idle_front_30fps_1x.mp4`: current original-speed views.
- `build_validation.json`/`closer_hold_build_validation.json`: current corrected build; `initial_support_build_validation.json` is the historical pre-correction build.
- `refinement_validation.json`: independent649-pose before/after comparison, exact body/head/leg transforms, preserved arm/rifle relations and reduced hand reach.
- `motion_validation.json`:649-pose rigid geometry, feet, rifle, adjacent seating and loop checks. No tolerance was increased for this correction.

## Source and preservation

The underlying v003 source-derived crossbow layers, source clocks, seeded attention gesture and documented rifle/rig adapters are unchanged. See its preserved `REFERENCE.md`. This remains research-only/nonproduction; the new holding-angle correction does not license the source-derived animation for commercial use.

All82other Showcase Actions and native rig/mesh/material/texture data stay exact. No Showcase entry is added or removed;35archived entries remain recoverable. The prior Pending v004 source, all its review files and the unsaved native Showcase are preserved under `/Users/tin/Documents/ChatGPT/New project/experiments/rifle_ready_idle_actionsstyle_v004/closer_hold_revision/`. Godot and approved v001/v002/v003 sources remain protected.

For regeneration, first build the initial support version using `authoring/build_candidate.py` from the pinned v003 source (explicit `--rebuild-pending` required if an output exists); then open that newly built v004 source and run `authoring/close_hold_revision.py`. Both scripts reject modifying an Approved v004. Keep a full Pending backup before regenerating. The current source is the corrected result, so running the correction twice is rejected by its input Action hash. The independent closer-hold validator takes the preserved initial v004 source path after `--`.
