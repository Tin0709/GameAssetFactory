# Rifle Ready Idle ActionsStyle v004 — left shoulder seating

**Pending Blender review, updated2026-10-17.** The user likes the previous closer hold and asks for the left shoulder to sit nearer the body shoulder. This refines the SAME v004; no new candidate or Showcase entry. The prior complete Pending source/reviews and unsaved native Showcase are preserved outside the repository under the `left_shoulder_revision_20261017` experiment. Approved v003 and all other Actions remain unchanged. No Godot integration.

Open the existing `blender/animation/showcase/Animation_Showcase.blend` → Animation Library → `Rifle_Ready_Idle_ActionsStyle_v004`. Actual Rifle Stylized V2 remains attached; Side view is selected. Space plays/pauses. F1–324 at30FPS, closing325 excluded,10.8second seamless loop.

## Current shoulder change

Only the left upper arm's3location and4quaternion channels change. The complete straight left arm pivots around the actual support-palm point. Its direction moves85% toward the closest reachable native shoulder socket, calculated from the animated Chest and unchanged rest bones. The15% remaining angular deviation retains some of the prior holding character. The extra correction is0.57–4.07° over the cycle; shoulder forward offset decreases4.9–35.1mm. Every one of649independent test poses is closer to the anatomical socket in full3D distance, not merely a better side projection.

The support palm's world path and position relative to the rifle remain exact to sub-micrometre numerical precision. The original0.9/1.8s breathing/support clocks, delayed micro pressure release and tangent movement therefore remain unchanged at the hand. Shoulder orientation is explicitly adapted by the socket projection; it is not claimed to retain the previous angular micro motion verbatim. Rifle, right arm, torso/head/root/legs and all their F-curves/evaluated world transforms remain unchanged. Existing key times/interpolation/modifiers and10.8second timing stay exact.

The accepted prior10° holding-set tuck,18mm vertical adjustment and20mm block-shoulder seating clearance remain in the base. This correction adds no rifle movement, elbow articulation, arm stretch, scale or rig/mesh change. Forearm local channels stay untouched. The socket-directed pivot can lower the left shoulder2.6–19.9mm and adjust its sideways position while bringing it nearer the native joint.

## Rig limit

A straight fixed-length arm with the current rifle/palm placement cannot reach the exact original rest socket: at the neutral pose, palm-to-socket distance is about719mm while shoulder-to-support-palm arm span is601mm. This is inherited from the source-to-rifle adaptation. The current adjustment moves the shoulder toward the closest reachable location on that fixed-length sphere, without secretly stretching the arm, changing the rifle or adding an elbow. It improves seating rather than claiming an exact anatomical reattachment. Visual acceptance remains with the user.

## Current review files

- `comparison_v004_left_shoulder_before_after_30fps.mp4`: previous accepted closer hold left, refined support shoulder right, same side camera/original speed.
- `comparison_v003_left_v004_right_30fps.mp4`: approved v003 versus current v004, three-quarter camera.
- `rifle_ready_idle_side_30fps_1x.mp4`, `rifle_ready_idle_three_quarter_30fps_1x.mp4`, `rifle_ready_idle_front_30fps_1x.mp4`: current original-speed views.
- `build_validation.json`/`left_shoulder_build_validation.json`: current shoulder build; `refinement_validation.json`: independent649-pose hand/socket/unaffected-motion comparison; `motion_validation.json`:649-pose geometry/contact/rigidity/loop checks.

`comparison_v004_before_after_side_30fps.mp4` and `closer_hold_build_validation.json` are historical reviews of the earlier10° whole-set tuck, not the current shoulder-only comparison. `initial_support_build_validation.json` records the earlier support-life stage. Their complete prior delivery files are also backed up externally.

## Preservation and regeneration

All82other Showcase Actions and native rig/mesh/material/texture data remain exact. The same48Action registrations plus2research sequences,15focused selectors and35archived selectors are retained. The previous Pending v004 source, reviews and unsaved native session are under `/Users/tin/Documents/ChatGPT/New project/experiments/rifle_ready_idle_actionsstyle_v004/left_shoulder_revision_20261017/`. Godot and the prior v001/v002/v003 study folders are protected byte-for-byte.

Regeneration has three guarded stages: run `authoring/build_candidate.py` from the pinned v003 source (explicit `--rebuild-pending` required for existing output), open that result and run `authoring/close_hold_revision.py`, then open the tucked result and run `authoring/seat_left_shoulder.py`. Each stage checks its input Action hash and rejects an Approved v004. Back up the Pending source before regeneration. The current corrected file cannot receive the shoulder correction twice. `authoring/validate_left_shoulder.py` takes the preserved tucked v004 source path after `--`; initial/closer-hold validators apply only to their corresponding earlier build stages.

Underlying source-derived crossbow layers, clocks and seeded attention remain research-only/nonproduction. See the preserved v003 `REFERENCE.md` for source files, controllers and original adaptation limits. This independently authored shoulder placement adapter does not license the underlying source reconstruction for commercial use.
