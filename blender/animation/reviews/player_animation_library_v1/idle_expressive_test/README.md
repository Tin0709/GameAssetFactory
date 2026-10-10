# Idle Expressive — pending review

`Idle_Expressive_Test` is a separate in-place, unarmed standing loop. It preserves the old Idle, all eight earlier showcase Actions, the original rigid full-arm/whole-leg character and its appearance. No rig rebuild, Godot edit, Walk work or Full Jump/preview change.

Playback is **1–96 at 30 FPS: 3.2 seconds**. Frame **97** is the matching closing key, excluded from playback. Each track has a Cycles modifier and matching endpoint tangents. The unequal left/right load and a longer quiet return give this small movement room to settle, rather than a steady metronomic bounce. Occasional looks, fidgets and gameplay transitions are outside this base-loop study.

## Review

- [All three views, original speed, three seamless repeats](idle_all_views_1x.mp4)
- [Old versus new — all three views, matching cameras and lighting](comparison_all_views_1x.mp4)
- [Old versus new — larger three-quarter comparison](comparison_three_quarter_1x.mp4)
- Individual [front](front_1x.mp4), [three-quarter](three_quarter_1x.mp4), [side](side_1x.mp4)
- [Pose sheet](idle_pose_sheet.jpg) and [decoded comparison/seam samples](decoded_comparison_samples.jpg)

Open the permanent [Animation Showcase](../../../showcase/Animation_Showcase.blend), select **Idle_Expressive_Test**, keep **Loop playback** enabled and press Play. The entry remains **Pending** until explicit user approval. The authoring source is `idle_expressive_review.blend`; this study is not another showcase.

The comparison uses actual saved `R12_Hold_Unarmed_Upper` from `../player_animation_library_v1.blend`, not a guessed neutral pose. Its native period is 96 frames at **24 FPS (4 seconds)**; it has a small 3 mm Spine translation. Those original poses are sampled every 0.8 source frames for the 30-FPS comparison, preserving speed. The new loop remains 3.2 seconds, so their phases gradually differ. Neither is stretched to match the other. The source stays unchanged. `old_idle_baseline.json` records the original Action/slot/source hash and evaluated geometry; background scene selection required refreshing mesh evaluation before sampling.

## Motion and evaluation

The hips transfer 15 mm across the stance, with only 2.5 mm of vertical variation. Both full soles stay planted throughout, with a 0.4 mm numerical floor margin. Existing leg pose channels compensate the very small hip shift; there are no new joints, boot rotations or replants. This carries the approved LowerBody Recovery softness into a much quieter standing rhythm.

Small chest/spine rotations suggest breath without mesh scaling. Right and left shoulders follow different timings and amplitudes; the relaxed arms remain separated from the torso, retaining the approved Arm Motion freedom at Idle scale. One degree of extra right-arm spread clears the head during the trailing response. The original 32 mm shoulder inset and rest rig are unchanged. Quiet head orientation counters torso movement so the face stays easy to read.

The strongest improvement over the old torso-only motion is the coordinated load shift with independent arm response. The three-quarter view reads that overlap most clearly; front shows planted support and asymmetry. The exact side view naturally hides some opposite-side articulation, so it is useful primarily for checking depth and foot contact. The motion deliberately remains subtle, and its appeal at small gameplay camera sizes still needs future in-game review. Rigid whole legs restrict deeper shifts; this Idle avoids needing them. A repeating 3.2-second base can eventually benefit from separate occasional variations, which are not authored here.

## Validation and preservation

`validation.json` covers 1,537 subframe samples: full-sole stability, rigid-part dimensions, floor clearance, nonadjacent block clearance, camera framing, root/scale constraints, loop pose and endpoint tangents, original Action signatures, appearance/rest/binding/material/texture/light fingerprints and source-comparison fidelity. `showcase_verification.json` checks a fresh reopen, all nine entries, original slots/ranges/FPS, switching/reset and evaluated source agreement. `gui_playback.json` records actual interactive looping after reopening. `media_verification.json` decodes every delivered video frame and checks frame counts, speed and correspondence to renders.

Backups and the concurrent-change baseline are under `.validation/idle_expressive_test/`; the first unapproved iteration is retained there as well. The protected-file audit includes every Full Jump review/preview file and Godot. Source and showcase are separate; only the new character Action is registered. All future character animations, including experiments and revisions, must be registered Pending in this same existing showcase under the permanent rule in `AGENTS.md` and `ANIMATION_WORKFLOW.md`.

Authoring helpers: `build_test.py` (refuses to overwrite an existing study), `validate_test.py`, `render_review.py`, `package_review.py`, `verify_showcase.py`. Re-rendering/packaging does not save or change any approved source.
