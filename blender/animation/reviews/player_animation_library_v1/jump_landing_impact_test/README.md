# Jump_Landing_Impact_Test — user approved / preferred landing baseline

**User approved, 2026-10-10. Preferred landing baseline.** The original `Jump_Landing_Test` remains preserved as the softer alternate. Earlier pending labels in the source/review videos and validation reports describe their delivery status; the approved Action and all review pixels remain unchanged.

**56 frames at 30 FPS.** A separate, heavier landing study. `Jump_Landing_Test` remains an independent 44-frame Action: its source, Action and every review file are unchanged. This variant is registered separately as **approved** after explicit user review and is now the preferred landing baseline.

## Watch the comparison

- [Three-quarter side-by-side, original speed](comparison_three_quarter_1x.mp4).
- [All three views, original versus impact](comparison_all_views_1x.mp4), plus separate [front comparison](comparison_front_1x.mp4) and [side comparison](comparison_side_1x.mp4).
- [Impact alone, all views](jump_landing_impact_1x.mp4): [front](impact_front_1x.mp4), [three-quarter](impact_three_quarter_1x.mp4), [side](impact_side_1x.mp4).
- [Unchanged original, all views](baseline_all_views_1x.mp4): [front](baseline_front_1x.mp4), [three-quarter](baseline_three_quarter_1x.mp4), [side](baseline_side_1x.mp4). These videos are byte-for-byte copies of the original review videos.
- [Phase comparison](phase_comparison.jpg), [impact poses](impact_pose_sheet.jpg), [decoded comparison samples](decoded_comparison_samples.jpg).
- [Saved study](jump_landing_impact_review.blend): `JUMP_LANDING_IMPACT_REVIEW`, `JI_Test_Rig`, `JI_Test_Mesh`, `Jump_Landing_Impact_Test`.
- [Animation Showcase](../../../showcase/Animation_Showcase.blend): N → Animation Library → `Jump_Landing_Impact_Test`, **APPROVED**.

Comparisons start together at the same AirPose continuation and retain **30 FPS / original timing**. First contact is F9 in both. The original ends at F44; its last 12 frames in the longer comparison are explicitly labeled **end holds**, while Impact continues to F56. No animation is slowed, stretched or silently looped. Cameras, character, materials, lighting and floor are the same. The phase sheet compares named phases at their own frames, not synchronized maximum poses.

## What was pushed

| Measure / phase | Original Landing | Impact variant |
| --- | --- | --- |
| First / second support | F9 / F11 | F9 / F10 |
| Deepest hip dip | F16, 90 mm below ready | F14, 120 mm below ready (+33%) |
| Contact → deepest dip | 7 frames | 5 frames |
| Peak local hip absorption speed | 0.453 m/s | 0.852 m/s |
| Receiving weight shift | Hip reaches x=30 mm | Hip reaches x=42 mm, farther toward lead support |
| Pelvis / spine / chest peak pitch | 7° / 8.5° / 5.5° | 9.5° / 11° / 7.5°, staggered |
| Recovery overshoot above ready | 7 mm at F26 | 12 mm at F30 |
| Final playback frame | 44 | 56 |

Approach retains approved AirPose F22 and its small ending angular velocity. The decisive second support arrives one frame after the lead foot. Hips absorb quickly, then remain near the bottom briefly as the spine/chest catch up. Arms make a broader independent counterbalance, with stronger rearward follow-through and different reversal times. Head motion grows only modestly. The rebound stays small and the longer final return gives weight rather than repeated spring motion.

**Assessment:** for the requested forceful touchdown, the variant reads as more satisfying and dramatic: faster/deeper absorption and the delayed torso/arms make momentum being received clearer. The single small rebound and slower settle keep the approved soft **“nhúng nhúng”** identity. The original remains the gentler comparison; the user has now selected the heavier variant as the preferred landing baseline. Future new Actions still require their own review.

**Rigid-leg limits:** deeper compression still uses the existing rigid-leg pose-translation/hip-overlap convention, not anatomical knees or ankles. Maximum leg-local translation is approximately **140 mm**, versus **108 mm** in the original and **149 mm** in approved LowerBody Recovery. This approaches the existing rig's practical compression range; pushing much deeper would risk an unattractive seam/hip overlap. Adjacent joint overlap remains part of the block assembly. Sampled nonadjacent intersections are absent. Soles rock around their planted lowest corner/edge; the entire sole is not falsely claimed fixed. Side projection naturally hides some paired-limb separation. Runtime impact speeds, controller transitions and moving landings remain untested.

## Safety, contact and continuity

Backups were created first under `.validation/jump_landing_impact_test/`, including the previous showcase, metadata, saved original Landing source and live Blender state. Registration also retains timestamped viewer/manifest backups. No rig rebuild, joints, constraints, scaling, model/proportion/material/texture edits or Godot modifications were made. Root is fixed; hip movement is local ground absorption/recovery. There is no extra full jump trajectory in the exportable Action.

[Validation](validation.json) samples **881 times at 1/16-frame spacing**, collision/framing at 1/8 frame. Maximum rigid-segment distance error is **0.266 micrometers**. Minimum sole height is approximately **0.399 mm** (the established 0.4 mm support margin); planted support height error stays below **0.007 mm**, horizontal support-corner error below **0.003 mm**. No sampled nonadjacent block intersections remain. The deeper pose uses at most 5 mm extra outward pose clearance per leg, without changing rest geometry or support anchors.

AirPose → Impact boundary position difference is **0.060 micrometers**; one-sided sampled velocity difference is **0.0021 m/s** including the existing external preview bridge, or **0.00016 m/s** for pose alone. The approved Takeoff → AirPose boundary is also retained/rechecked. `review_scene.py` keeps world approach translation external and floor-consistent; it is not a physically calibrated jump arc and does not create a combined Action/NLA track. The rendered comparisons use identity rig transforms and the normal floor for both landings, isolating articulation and ground absorption rather than presenting different world trajectories.

[Showcase checks](showcase_verification.json) reopen the seven-entry library, exercise **23 switches**, verify slots/ranges/FPS, source geometry, floor/pose reset, one rig/character and **2,368 protected file hashes**. All six pre-existing Actions remain unchanged, including the original Landing. That historical delivery had both landing entries pending; Impact is now explicitly approved and preferred. [GUI playback](gui_playback_verification.json) checks actual reopened advancement and stopping at F56.

[Media verification](media_verification.json) decodes all 12 videos, checks counts/FPS/dimensions and compares every frame with source pixels. The original PNGs/videos are preserved byte-for-byte; a fresh baseline F16 three-quarter render checks that the copied stage and original Action still produce identical pixels.

Reproduction: `build_test.py`, `validate_test.py`, `review_scene.py`, `render_review.py`, `package_review.py`, `verify_showcase.py`. The builder refuses to overwrite a saved study. Preserve/version revisions and use [the registration workflow](../../../showcase/README.md). This is isolated Blender comparison material; no full production jump or gameplay integration is authorized.
