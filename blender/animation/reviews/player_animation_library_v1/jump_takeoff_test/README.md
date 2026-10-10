# Jump_Takeoff_Test — user approved

**24 frames at 30 FPS (0.8 s playback). Takeoff only:** ready, anticipation, soft compression, upward push, liftoff and early flight. There is no apex, descent or landing. The Animation Showcase and the three reference tests are user approved; the user explicitly approved this Action on 2026-10-10, including its expressive motion and soft, subtle pre-launch compression.

## Review

- [Three-view review video](jump_takeoff_review.mp4): three 1x replays with labeled end holds/cuts. The cut back to ready is not a landing or seamless loop.
- [Uninterrupted 1x video](jump_takeoff_1x.mp4), 24 actual sequential renders.
- Individual views: [front](front_1x.mp4), [three-quarter](three_quarter_1x.mp4), [side](side_1x.mp4).
- [Key poses](takeoff_pose_sheet.jpg), [same-setup compression comparison](compression_comparison.jpg), complete [front](front_all_frames.jpg), [three-quarter](three_quarter_all_frames.jpg) and [side](side_all_frames.jpg) sheets.
- [Saved Blender study](jump_takeoff_review.blend): `JUMP_TAKEOFF_REVIEW`, `JT_Test_Rig`, `JT_Test_Mesh`, independent Action `Jump_Takeoff_Test`.
- Also available in [Animation Showcase](../../../showcase/Animation_Showcase.blend), N → Animation Library, visibly **APPROVED**. Select it and Play; loop is initially off so it stops in early flight.

## Approved baseline carried forward

`LowerBody_Recovery_Test` provides the main artistic reference: a small lateral transfer, a light counter-bounce, a readable dip and delayed torso support. This takeoff uses **108 mm** of hip compression, slightly shallower than recovery's 126 mm, and retains the controlled, soft “nhúng nhúng” quality. It redirects recovery upward instead of adding a deeper squat.

`Expressive_Arm_Motion_Test` supplies broad, clearly separated FK arm arcs. The right arm leads the forward/upward swing slightly; the left follows, avoiding a mechanically mirrored launch. `Run_Expressive_Test` supplies pelvis/torso opposition, silhouette separation and restrained head behavior. The chest follows the push while the head keeps a quiet gaze with a small delayed nod. All poses and timings in this Action are original, authored on the existing rig.

| Frame | Purpose |
| --- | --- |
| 1–4 | Stable ready pose |
| 7–9 | Small lateral load and soft counter-bounce |
| 13–14 | Soft pre-launch dip, arms prepared behind/outside the body |
| 15–18 | Accelerating upward recovery; arms gather into the swing |
| 19 | Last supported pose, body length restored |
| 20 | First whole rendered airborne frame |
| 21–24 | Arm follow-through and modest asymmetric leg separation; test ends rising |

## Evaluation

**Improved:** the dip and release now form one purposeful impulse. Supported soles establish weight before flight; the body rises as the arms open, giving a clearer compact-to-open silhouette. The torso reacts to the push and the head stays controlled. Front and three-quarter views read the arm width; side view reads the dip, arm preparation and ground separation. The final pose is a starting point for airborne work, rather than a finished aerial hold.

**Still limited:** the unchanged whole-leg cuboids have no knee articulation or independent toe joint. Compression therefore uses the already approved shallow hip overlap and rigid edge/corner support, limiting how deep a convincing squat can go. The arm passage through push-off is deliberately quick and is the main timing item for user review. An airborne-pose study still needs to refine the sustained silhouette and its eventual handoff; landing and runtime transitions are untested.

**Subsequent approval and next stage:** the user approved this takeoff and its soft, subtle compression, then requested the separate [Jump_AirPose_Test](../jump_airpose_test/README.md). That new Action remains pending. Takeoff approval does not establish readiness for full jump production.

## Validation and preservation

[Saved-file geometry checks](validation.json) inspect 369 evaluated times at 1/16-frame intervals, with collision/framing checks at 1/8-frame intervals. Maximum rigid-segment distance error is **0.294 micrometers**. No sampled floor penetration or nonadjacent block intersections; ground contact remains within 0.401 mm of the floor through F19, including the intentional 0.4 mm support margin. All three cameras contain the actor. No limb scale tracks, rig rebuild, new constraints, materials, UVs, weights or proportion changes.

The minimal study preserves the three approved Action copies unchanged and adds only the takeoff. All original study/master files and protected Godot resources retain their hashes; no legacy library was rewritten or bulk-imported. [Showcase checks](showcase_verification.json) verify fresh reopening, slot/range/timing binding, switching back into partial reference Actions and source geometry agreement within **0.141 micrometers**. The source slot identifier is retained explicitly; identifiers are local to each Action and need not match the renamed rig's display name.

[Media verification](media_verification.json) decodes the generated MP4s, verifies frame count/FPS/dimensions and compares the composite to every corresponding rendered image. Videos show Blender-only motion, not Godot runtime behavior. No export or Godot modification was performed.

Backups precede authoring/registration: `.validation/jump_takeoff_test/` contains the saved/live showcase, manifest, affected documentation, approved recovery copy and protected-file SHA256 manifest. Registration also creates its normal timestamped backup under `.validation/animation_showcase/registrations/`.

`build_test.py` authors/bakes the single Action from the backed-up showcase; `validate_test.py`, `render_review.py`, `package_review.py` and `verify_showcase.py` reproduce checks/media. Do not rebuild over a reviewed source: retain a versioned backup first. Register revisions under a new Action name; keep status pending until explicit user approval. See [the library workflow](../../../showcase/README.md).
