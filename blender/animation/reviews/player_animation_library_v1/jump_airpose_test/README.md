# Jump_AirPose_Test — user approved

**User approved 2026-10-10:** happy with its expressive airborne motion. The approved Action and saved Blender source remain unchanged.

Older video captions, validation reports and the saved source's authoring label retain their historical pending status. Current approval is recorded in the manifest, Animation Progress and the showcase. [Jump Landing](../jump_landing_test/README.md) is the subsequent pending study.

**22 frames at 30 FPS.** An in-place airborne articulation study that continues the now **user-approved Jump_Takeoff_Test**. Silhouette is the primary artistic objective. The original takeoff Action and saved source are unchanged; approval is recorded in [Animation Progress](../../../../../docs/animation/ANIMATION_PROGRESS.md).

## Review output

- [Approved takeoff → pending AirPose review](takeoff_to_airpose_review.mp4): front, three-quarter and side together, three 1x replays with labeled end holds/cuts.
- [Uninterrupted transition](takeoff_to_airpose_1x.mp4), 45 rendered frames at 30 FPS. Takeoff F24 and AirPose F1 share a boundary; that endpoint is not duplicated as an extra held frame.
- [AirPose alone](jump_airpose_1x.mp4), with individual [front](front_1x.mp4), [three-quarter](three_quarter_1x.mp4) and [side](side_1x.mp4) videos.
- [Key silhouettes](air_pose_sheet.jpg), [boundary comparison](boundary_pose_comparison.jpg), complete [front](front_all_frames.jpg), [three-quarter](three_quarter_all_frames.jpg) and [side](side_all_frames.jpg) sheets.
- [Saved Blender study](jump_airpose_review.blend): `JUMP_AIRPOSE_REVIEW`, `AP_Test_Rig`, `AP_Test_Mesh`, Action `Jump_AirPose_Test`.
- [Animation Showcase](../../../showcase/Animation_Showcase.blend), N → Animation Library → `Jump_AirPose_Test`, visibly **APPROVED**.

## Motion and evaluation

The takeoff's final shoulder, torso, head and leg articulation forms the first airborne pose. The right arm follows the launch slightly upward before relaxing into a broad open direction; the left develops its arc later. The lead leg reaches its clearest split around F9, the trailing leg follows around F13, and the torso counter-turn remains small. The head retains a readable, quiet gaze. Late poses continue to evolve with small, purposeful changes rather than freezing or cycling all limbs together.

The observed Dungeons II jump sequence in the [style guide](../../../../../docs/animation/ANIMATION_STYLE_GUIDE.md) informs compact-to-open contrast, asymmetric legs and exposed arms. Its apparent later pose similarity is not treated as evidence of a runtime limb-freeze rule. This test uses original poses/timing on our existing character.

**Improved:** the lead/trail leg split opens further than takeoff; modest outward hip articulation makes it readable from the front and three-quarter views as well as the side. Arms remain clearly separated from the torso, with staggered changes and restrained counter-rotation. A first-pass sub-millimeter leg overlap was removed with a pose-only clearance of at most 2 mm extra per side. No bone, joint, weight or mesh was added or changed.

**Still limited:** whole-leg and whole-arm blocks provide no knee/ankle articulation. Side view naturally overlaps the paired arms more than front/three-quarter. The final pose is a continuation sample, not a finished transition to landing or an arbitrary-duration runtime air loop. Duration/blending under actual controller physics remains untested. The user has explicitly approved AirPose; subsequent landing remains a separate pending study.

## In-place pose versus temporary presentation

The approved takeoff includes a small baked rise. AirPose removes that common vertical travel from its new starting pose and holds **Root and Hips translation constant** at the established 0.674 m hip reference. There is no authored jump trajectory, vertical bob, root travel or ground-contact bounce in this Action. Grounded “nhúng nhúng” remains the approved takeoff/recovery style; flight uses angular overlap and asymmetry.

For the temporary transition video, `review_scene.py` selects the two separate Actions per frame. An external, non-exported preview offset restores takeoff's final height and smoothly carries its entry translation velocity into a fixed-height review display over six frames. It is a presentation bridge, not a ballistic arc or runtime implementation. No new combined Action, NLA track or production jump is created; no apex/descent/landing is authored.

Standalone AirPose and its showcase entry lower only the review floor by a fixed 0.197083 m. The character remains at identity object transform. The manifest's `preview_floor_z_m` is validated and reset to zero when another clip is selected. This keeps a clear airborne preview without putting additional height into the Action or controller.

## Validation and preservation

[Saved-file checks](validation.json) sample 337 times at 1/16-frame spacing, with collision/framing at 1/8 spacing. Maximum rigid-segment distance error is **0.265 micrometers**; there are no sampled nonadjacent block intersections. Hip position range is zero in all three axes. No scale tracks, rig rebuild, constraints, new joints or appearance changes.

At the normalized shared boundary, maximum evaluated vertex position difference is **0.321 micrometers**. The measured one-sided velocity difference is **0.00822 m/s** at 1/8-frame spacing, including the separate preview carry. These are finite sampled checks, not a claim of mathematically identical derivatives at all scales. The boundary comparison and decoded transition frames provide the corresponding visual review.

[Showcase verification](showcase_verification.json) covers fresh reopening, all five entries, original slots/ranges/timing, partial-pose reset, stage reset and source geometry agreement. The four existing Actions retain their fingerprints. Protected original/master study files, including approved takeoff, and Godot resources retain their SHA256 hashes. No Godot/export/controller modifications were made; this is Blender-only evidence.

[Interactive playback verification](gui_playback_verification.json) confirms the reopened showcase plays AirPose at 30 FPS, advances through the Action, and stops at frame 22 with Loop disabled. The library lists four approved references and AirPose as pending.

[Media verification](media_verification.json) checks decoded frame counts/FPS, records dimensions, and compares every frame of the two uninterrupted composite videos to its rendered source. The first 24 transition frames reuse the approved takeoff render files byte-for-byte. Replays end with explicit holds/cuts, not an invented landing or seamless loop.

Backups and the rejected first pass are retained under `.validation/jump_airpose_test/`; registration also creates a timestamped library backup. Reproduction scripts are `build_test.py`, `validate_test.py`, `review_scene.py`, `render_review.py`, `package_review.py` and `verify_showcase.py`. The builder refuses to overwrite a saved study. Keep revisions versioned and pending until explicit user approval; follow [the library workflow](../../../showcase/README.md).
