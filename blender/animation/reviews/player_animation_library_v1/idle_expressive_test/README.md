# Idle Expressive — pending review

`Idle_Expressive_Test` is a separate in-place, unarmed standing loop. It preserves the old Idle, all eight earlier showcase Actions, the original rigid full-arm/whole-leg character and its appearance. No rig rebuild, Godot edit, Walk work or Full Jump/preview change.

Playback is **1–144 at 30 FPS: 4.8 seconds**. Frame **145** is the matching closing key, excluded from playback. Each track has a Cycles modifier and matching endpoint tangents. The user subsequently supplied a Minecraft Dungeons II Player Idle LookAround GIF and requested this same pending Action gain curiosity and intentional pauses. The [user-supplied GIF](references/minecraft_dungeons_ii_idle_lookaround.gif) has 81 frames totaling 3.38 seconds. Its head-led attention and delayed body response inspire the motion; exact source joint angles are not inferred from pixels. A longer period gives our glance, observation and rest room to breathe. Extra fidgets and gameplay transitions remain outside this study.

## Review

- [All three views, original speed, two seamless repeats](idle_all_views_1x.mp4)
- [Old versus new — all three views, matching cameras and lighting](comparison_all_views_1x.mp4)
- [Old versus new — larger three-quarter comparison](comparison_three_quarter_1x.mp4)
- Individual [front](front_1x.mp4), [three-quarter](three_quarter_1x.mp4), [side](side_1x.mp4)
- [Pose sheet](idle_pose_sheet.jpg) and [decoded comparison/seam samples](decoded_comparison_samples.jpg)

Open the permanent [Animation Showcase](../../../showcase/Animation_Showcase.blend), select **Idle_Expressive_Test**, keep **Loop playback** enabled and press Play. The entry remains **Pending** until explicit user approval. The authoring source is `idle_expressive_review.blend`; this study is not another showcase.

The comparison uses actual saved `R12_Hold_Unarmed_Upper` from `../player_animation_library_v1.blend`, not a guessed neutral pose. Its native period is 96 frames at **24 FPS (4 seconds)**; it has a small 3 mm Spine translation. Those original poses are sampled every 0.8 source frames for the 30-FPS comparison, preserving speed. The new loop remains 4.8 seconds, so their phases gradually differ. Neither is stretched to match the other. The source stays unchanged. `old_idle_baseline.json` records the original Action/slot/source hash and evaluated geometry; background scene selection required refreshing mesh evaluation before sampling.

## Motion and evaluation

| Phase | Frames | Intent |
| --- | --- | --- |
| Relaxed rest | 1–22 | Comfortable stillness with very quiet rigid breathing |
| Head leads glance | 23–37 | Clear attention shift; body begins to follow later |
| Observe / body settles | 38–69 | Hold attention, delayed torso/hip/arm response |
| Return and settle | 70–124 | Head returns first, torso and arms finish later |
| Rest across seam | 125–144 → 1–22 | Long quiet boundary; closing key145 excluded |

The hips transfer 13 mm across the stance, with about 1 mm of vertical variation. Both full soles stay planted throughout, with a 0.4 mm numerical floor margin. Existing leg pose channels compensate the very small hip shift; there are no new joints, boot rotations or replants. This carries the approved LowerBody Recovery softness into a much quieter standing rhythm.

Small chest/spine rotations suggest breath without mesh scaling. Right and left shoulders follow different timings and amplitudes; the relaxed arms remain separated from the torso, retaining the approved Arm Motion freedom at Idle scale. During the glance the shoulders relax downward by up to 18 mm, with smaller independent offsets and delayed rotations; this gives the turning rigid head clearance. The near arm also eases forward about 8 degrees as a counterbalance, on its own slightly delayed curve, clearing the rotating head. These are existing pose channels, not rest-rig or proportion changes. The original 32 mm shoulder inset and rest rig are unchanged. The head leads a roughly 27-degree glance, with a tiny upward orientation/tilt. The torso follows by about 7 degrees and the hips by 1.2 degrees, while the arms trail independently. The face remains readable.

The strongest improvement over the old torso-only motion is the purposeful observation, coordinated load shift and independent arm response. The three-quarter view reads that overlap most clearly; front shows planted support and asymmetry. The exact side view naturally hides some opposite-side articulation, so it is useful primarily for checking depth and foot contact. The motion deliberately remains subtle, and its appeal at small gameplay camera sizes still needs future in-game review. Rigid whole legs restrict deeper shifts; this Idle avoids needing them. A repeating 4.8-second curious Idle can eventually be scheduled as an occasional variant alongside a quiet base Idle to avoid an overly predictable glance; no additional Action or controller behavior is authored here.

## Validation and preservation

`validation.json` covers 2,305 subframe samples: full-sole stability, rigid-part dimensions, floor clearance, nonadjacent block clearance, camera framing, root/scale constraints, loop pose and endpoint tangents, original Action signatures, appearance/rest/binding/material/texture/light fingerprints and source-comparison fidelity. `showcase_verification.json` checks a fresh reopen, all nine entries, original slots/ranges/FPS, switching/reset and evaluated source agreement. `gui_playback.json` records actual interactive looping after reopening. `preservation_verification.json` checks the original working-tree bytes, including pre-existing concurrent work. `media_verification.json` decodes every delivered video frame and checks frame counts, speed and correspondence to renders.

Measured saved-source results: no nonadjacent overlaps; full-sole drift below **0.001 mm**; exact closing pose match; endpoint channel-tangent difference **6.1×10⁻¹¹**; finite near-seam vertex-velocity difference **8.7×10⁻⁵ m/s**. The observed pose has head yaw **26.7°**, torso yaw **6.93°**, side lean **1.77°** and hip yaw **1.20°**. These are Blender measurements, not runtime transition or phone-performance results. Validation, showcase reopening and GUI playback reports identify the exact source/Action hashes, preventing stale passes from validating a later revision.

Backups and the concurrent-change baseline are under `.validation/idle_expressive_test/`; discarded working iterations of this same Pending Action are retained there as well, including the quiet breathing pass and a torso-axis refinement; these are not separately named library Actions. The protected-file audit includes every Full Jump review/preview file and Godot. Source and showcase are separate; only the new character Action is registered. All future character animations, including experiments and revisions, must be registered Pending in this same existing showcase under the permanent rule in `AGENTS.md` and `ANIMATION_WORKFLOW.md`.

Authoring helpers: `build_test.py` (refuses to overwrite an existing study), `validate_test.py`, `render_review.py`, `package_review.py`, `verify_showcase.py`. The task-local `revise_pending_registration.py` records the explicitly requested same-name Pending refinement with source/viewer/manifest guards and backups; it does not permit approved replacements. Re-rendering/packaging does not save or change any approved source.
