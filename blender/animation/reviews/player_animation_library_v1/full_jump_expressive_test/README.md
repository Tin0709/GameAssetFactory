# Full_Jump_Expressive_Test — pending review

**93 frames at 30 FPS (3.10 seconds), one independent in-place Action.** This is the first complete expressive jump study, using approved Takeoff, AirPose and the now-approved preferred Impact Landing. The softer original Landing remains preserved as an alternate. No existing Action, rig, character asset or Godot file is changed.

## Review

- [Full jump, all three views at original speed](full_jump_all_views_1x.mp4).
- Separate [front](front_1x.mp4), [three-quarter](three_quarter_1x.mp4) and [side](side_1x.mp4), all 93 frames at 30 FPS.
- [Three-quarter pose sheet](three_quarter_pose_sheet.jpg), [all-view pose sheet](full_jump_pose_sheet.jpg), [decoded video samples](decoded_video_samples.jpg).
- [Reusable source](full_jump_expressive_review.blend): `FJ_Test_Rig`, `FJ_Test_Mesh`, **Full_Jump_Expressive_Test**. Rig object and Root remain stationary; no flight trajectory is in the Action.
- [Blender-only moving review](full_jump_preview.blend): the same pose Action plus a separate parent Empty, `Review_Only_Jump_Travel`, with `PREVIEW_ONLY_FullJump_Height`. Play F1–93. **Do not export this parent/height Action.** Its 0.58 m presentation arc is not a gameplay physics specification.
- [Animation Showcase](../../../showcase/Animation_Showcase.blend): select **Full_Jump_Expressive_Test**, marked **PENDING**. The library previews the reusable in-place poses on the normal floor; use the video or separate preview file to see the complete elevated jump. Flight foot heights in the in-place clip are not physical ground contacts.

## Motion and continuity

| Full frames | Phase / design |
| --- | --- |
| 1–19 | Approved ready, light load/counter, 108 mm soft preparation dip and upward push; actual support retained through F19 |
| 20–24 | Liftoff and early arm release; the takeoff study's common vertical rise is removed from the new Action |
| 24–38 | Approved AirPose silhouettes and independent limb overlap, with a shorter middle to avoid a suspended pose-study hold |
| 38–46 | Approved Impact approach; lead support at F46, second support F47 |
| 46–55 | Faster, deeper approved absorption: 120 mm hip drop, delayed torso/arms and quiet head |
| 55–67 | Controlled recovery impulse; just 12 mm above-ready rebound at F67 |
| 67–93 | Weighted settle to movement-ready stance; no repeated spring motion |

The shared endpoints at F24 and F38 occur once. AirPose's 21 source-frame intervals occupy 14 full-jump intervals using `source = 1 + t + 7*smooth5(t/14)`. Endpoint source speed is one, with zero time-warp acceleration; this preserves the incoming/outgoing motion instead of abruptly multiplying all airborne velocities. Grounded takeoff and heavy landing keep their approved timing and poses. Arms, pelvis/chest and head retain their different reversal times.

Preview elevation has one continuous rise/apex/descent, zero offset through last support and from lead contact onward. The first half-frame eases release acceleration. Contact arrests downward world travel while local hip/torso absorption continues; this intentional impact deceleration is separate from the smooth pose-phase boundaries. The preview cameras are widened to fit the arc; materials, lights and character stay the same. The source and showcase retain the original stage cameras.

## Evaluation

**What works best:** compact soft preparation opens into a wide, asymmetric airborne silhouette, then closes toward decisive staggered contact. The shorter moving air section connects launch to descent, and the stronger landing gives the full gesture a clear finish. The delayed torso/arm absorption and slow final settle preserve the approved **nhúng nhúng** character without adding aerial bounce or repeated rebounds. The three-quarter view communicates arm separation and weight transfer best; the side view clearly exposes the leading/trailing rigid legs and torso reaction.

**Remaining limits:** whole rigid legs cannot make a knee-driven squat or ankle roll. Compression uses the existing accepted shallow hip overlap and rocking sole corner/edge support; a fully flat sole is not held throughout. Front projection partly hides the fore/aft leg split. The 3.10-second study deliberately includes readable preparation and a long recovery; input latency, early movement cancellation, variable jump height and uneven-ground contacts still need controller work. This is a one-shot with a receiving stance different from its starting stance, not a seamless cycle.

**Readiness:** suitable for a subsequent Godot-side controller/blending experiment after user review. Keep physics responsible for the world arc, align contact/absorption to actual landing, and allow recovery to blend into movement. No export, runtime integration or runtime quality claim is made here. Full Jump remains pending until explicitly approved.

## Validation and preservation

[Saved-file validation](validation.json) samples 1,473 times, with collision/framing checks every eighth frame. [Showcase verification](showcase_verification.json) checks fresh reopening, all eight independent slots/ranges/statuses and repeated switching against evaluated source geometry. [GUI playback verification](gui_playback_verification.json) records playback advancing and stopping at F93 after reopening. [Asset verification](asset_verification.json) checks mesh/rest/weights/UVs/materials/packed images, the separate preview travel and original Action signatures. [Media verification](media_verification.json) decodes all four original-speed videos, checking every frame against its render input.

Measured pose-phase velocity differences are approximately **0.00692 m/s at F24** and **0.000157 m/s at F38**, with normalized source pose agreement within **0.54 μm** at baked sample times. Planted support height stays within **6.1 μm**, horizontal support anchors within **0.013 mm**, and rigid geometry error within **0.28 μm**. No nonadjacent block intersections or preview-floor penetration were detected. Intentional adjacent shoulder/hip overlaps are excluded from collision rejection and inspected in the renders.

[Final preservation audit](preservation_verification.json) confirms all 2,695 protected files and all eight registered source hashes. Backups and SHA256 baseline: `.validation/full_jump_expressive_test/`. The seven pre-existing study Actions and source blends, softer Landing review material, production assets and Godot remain protected. Only approval/progress/library metadata and the saved showcase are updated; Impact's approved source and review videos are unchanged. Registration uses the in-place source only, retains the original Blender 5.2 slot, and imports no preview travel or additional character/rig.
