# Jump_Landing_Test — pending user review

**44 frames at 30 FPS.** An isolated landing study continuing the now **user-approved Jump_AirPose_Test**. AirPose approval is recorded in [Animation Progress](../../../../../docs/animation/ANIMATION_PROGRESS.md), source metadata and the showcase. Its approved saved Blender source and Action are unchanged.

## Review material

- [Takeoff → AirPose → Landing, original speed](takeoff_airpose_landing_1x.mp4): 88 frames / 2.933 seconds, all three views. Shared endpoints appear once, without duplicate boundary holds.
- [Two review replays](takeoff_airpose_landing_review.mp4), with explicit end holds/cuts.
- [Landing alone, all three views](jump_landing_1x.mp4), and separate [front](front_1x.mp4), [three-quarter](three_quarter_1x.mp4) and [side](side_1x.mp4) clips.
- [Landing poses](landing_pose_sheet.jpg), [approved recovery comparison](recovery_comparison.jpg), [decoded transition samples](decoded_transition_samples.jpg).
- [Saved study](jump_landing_review.blend): `JUMP_LANDING_REVIEW`, `JL_Test_Rig`, `JL_Test_Mesh`, independent `Jump_Landing_Test` Action.
- [Animation Showcase](../../../showcase/Animation_Showcase.blend): N → Animation Library → `Jump_Landing_Test`, **PENDING**.

## Motion and evaluation

| Phase | Landing frames | Design |
| --- | --- | --- |
| Approach | 1–8 | Preserve AirPose's ending articulation, then bring the asymmetric legs toward support while the open arms start preparing. |
| Contact | 9 / 11 | Lead left sole receives first, right follows two frames later. Actual lowest sole corners/edges anchor to fixed floor positions. |
| Compression | 9–16 | Hip height falls from 0.663 m at first contact to 0.584 m. The pelvis shifts toward receiving support, with torso absorption following. |
| Overlap / rebound | 17–29 | Torso/chest and arms respond later than the hip dip. Hips recover to 0.681 m, only 7 mm above ready height. |
| Recovery | 30–44 | Settle smoothly to 0.674 m, with a quiet head and stable staggered stance; no second bounce. |

**Improved:** meaningful support replaces the airborne split without a pose reset. The small hip dip, restrained overshoot and slower settling carry forward the approved **“nhúng nhúng”** language. Arms remain separated from the torso and recover at different times; the head follows quietly. The new dip is **90 mm below ready**, compared with **126 mm** in approved LowerBody Recovery. Both use the existing rigid-leg ground-corner mechanism, not scaled limbs or invented joints. The comparison sheet matches named phases; the animations retain their own original timing.

**Limitations:** whole rigid legs cannot squat with anatomical knees/ankles. Compression therefore uses the existing pose translation/hip-overlap convention; maximum leg-local translation is approximately **108 mm**, below the recovery reference's **149 mm**. This is a genuine rig limitation, not a claim of anatomical mechanics. Inspect the close front/three-quarter views before approval. Paired arms and legs naturally overlap more in side projection. Support means a planted lowest corner/edge while the rigid sole rocks; it does not mean every sole vertex stays fixed. Runtime blending, moving gait transitions, different impact velocities and variable-duration flight remain untested.

## Pose versus presentation travel

Root stays fixed. Landing contains approach articulation and local ground compression/recovery, with no extra full jump trajectory, horizontal world travel or scaled bones. The first pose equals approved AirPose F22; the last tiny angular velocity is carried into the new Action before its own timing develops. No rig, bone, joint, constraint, mesh, texture or material was changed.

`review_scene.py` selects three independent Actions in a temporary rendering process. It reuses the approved takeoff/air review presentation, then eases its external preview offset to zero by first contact. This is a floor-consistent viewing bridge, not a physically calibrated ballistic jump. Airborne presentation and local ground compression are separate. No combined Action, NLA sequence or controller/export change is saved. Standalone Landing uses the normal fixed floor and identity rig transform; AirPose's lowered showcase floor resets when Landing is selected.

## Validation and preservation

[Saved-file validation](validation.json) samples **689 times at 1/16-frame spacing**, with collision/framing checks at 1/8 frame. Maximum rigid distance error is **0.233 micrometers**; no sampled nonadjacent block intersections remain. Minimum sole height is approximately **0.400 mm** (the existing support margin); planted support height error stays below **0.020 mm**, and support-corner horizontal error below **0.002 mm**. The first pass's sole-sweep penetration and sub-millimeter leg collision are archived; monotone approach clearance and at most 3 mm extra pose clearance per side resolve them.

AirPose → Landing boundary position error is **0.060 micrometers**. One-sided sampled velocity difference is **0.0021 m/s** including preview descent, or **0.00016 m/s** for pose alone. The retained Takeoff → AirPose boundary is rechecked. These finite samples support visual inspection, not a claim of identical derivatives at every scale. The complete temporary sequence also passes sampled floor/framing checks.

[Showcase verification](showcase_verification.json) reopens the saved six-entry library, checks 19 selection transitions, original slots/ranges/FPS, neutral-pose and floor resets, source geometry, one character/rig, five unchanged approved Actions and **1,944 protected file hashes**, including approved sources and Godot. [Interactive playback](gui_playback_verification.json) checks the reopened Landing playback and one-shot stop. [Media verification](media_verification.json) decodes every output, checks frame counts/FPS/dimensions and compares every decoded frame with its source. The first 45 combined-review frames reuse the earlier approved-phase review PNGs byte-for-byte.

Backups and the rejected first pass remain in `.validation/jump_landing_test/`; registration also retains timestamped manifest/viewer backups. Reproduction scripts are `build_test.py`, `validate_test.py`, `review_scene.py`, `render_review.py`, `package_review.py` and `verify_showcase.py`. The builder refuses to overwrite a saved study. Preserve/version revisions and keep them pending until explicit user approval, following [the library workflow](../../../showcase/README.md).

This is Blender-only artistic review material. No full production jump or Godot integration was begun.
