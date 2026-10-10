# Idle Expressive v3 — support-led standing refinement

2026-10-11. **Pending user review.** Separate Action `Idle_Expressive_Test_v3`; v2/v1 and every earlier Action, source and review remain preserved. Blender-only artistic study, not production-ready or Godot-validated.

Open the existing [Animation Showcase](../../../showcase/Animation_Showcase.blend), select **Idle_Expressive_Test_v3** in N → Animation Library, enable Loop and Play. Both earlier Idle versions remain selectable. [Separate authoring source](idle_expressive_v3_review.blend) uses the same rest rig, mesh, materials, packed textures, lights and three cameras.

Playback **1–240 at 30 FPS**, eight seconds. Closing key **241 is excluded** from playback. Each review video shows two complete loops at original speed, with no retiming, closing-key hold or padding.

## Review

- [V3 front / three-quarter / side together](idle_v3_all_views_1x.mp4).
- [V2 versus v3 — all three matching views](comparison_all_views_1x.mp4).
- [V2 versus v3 — three-quarter comparison](comparison_three_quarter_1x.mp4).
- Individual [front](front_1x.mp4), [three-quarter](three_quarter_1x.mp4), [side](side_1x.mp4).
- [Front stance comparison](stance_comparison_front.jpg).
- [Three-view key poses](idle_v3_pose_sheet.jpg) and [decoded comparison samples](decoded_comparison_samples.jpg).

V2's unchanged source reproduces its saved evaluated vertices within 0.000369 mm on the v3 study rig. Its original PNGs are reused at the same camera, lighting and timing; both versions have the same 240-frame period. No appearance adjustments make either version look better.

## How the stance changed

V2 placed two upright parallel legs at X ±140.5mm. The latest [standing image and user correction](references/sideways_stance_target.png) clarify the target: the whole legs open **mainly sideways**, rather than reaching forward like a running step. V3 keeps **Leg.L** as firmer support (character left, screen right in front view), with a more relaxed **Leg.R**. Both foot width edges face forward: **zero external toe-out yaw**. Both feet stay at the same depth; forward/backward leg pitch is zero.

| Relationship | V2 | Latest corrected v3 |
| --- | --- | --- |
| Support leg | Upright, equally weighted appearance | Whole Leg.L opens sideways 3°; hips biased 28mm toward support |
| Relaxed leg | Upright parallel to support | Whole rigid Leg.R opens sideways 8°; no forward reach |
| Placement logic | Both legs translated outward equally | Proximal leg pair follows hip bias by 20mm; unequal lateral angles open the base |
| Torso/pelvis | Mostly centered over wider feet | Restrained support-side rise, torso counterbalance and unequal arms |
| Breathing | Tiny 1.8mm chest lift | Slow 6mm hip/body rise plus existing chest lift over four seconds; legs fixed |

**Contact and rigid-leg limitation:** both angled boots rest along fixed outer sole edges. Their inner sole edges rise with the solid blocks; neither boot is deformed or flattened, and no ankle/knee joint is invented. Every sole vertex remains stationary. A 0.4mm numerical stage margin is retained. This is stable artistic edge contact rather than full-flat anatomical foot support. The upright-foot, forward-reaching and earlier yawed working passes were archived under `.validation/idle_expressive_test_v3/` before this explicit correction. None is approved.

The user's final emphasis is each leg's **angle relative to the body**, not independent foot placement. The proximal leg pair follows the supported pelvis, and the restrained torso lean counterbalances above it. [Measured authored body/leg axes](relative_body_angles.json) compare rest, both observing poses and breathing extrema: the firmer leg stays closer to the torso axis, the relaxed leg opens farther sideways, and neither reaches forward. These are our authored angles, not exact 3D angles recovered from a single reference image.

## Retained performance and evaluation

Two unequal head-led interests remain: first look begins F25, observes F49–75 and returns toward center by F104; the second begins F125, observes F146–164 and returns by F194. Torso, hips and arms follow with their original staggered timing and settle by F218. Comfortable rest spans the loop seam. World head yaw remains approximately +25.7° / −23.3°, with restrained chin/tilt response.

The independent four-second breathing-like layer retains a maximum 1.8 mm rigid chest lift, tiny shoulder response and delayed head life. The user-requested slow body rise and settle has6mm hip excursion; feet remain compensated and fixed. No facial controls, blink, scaling, deformation, new rig controls or random motion were added.

**Assessment:** the sideways opening now addresses the user's distinction directly: a relaxed open standing base, without the previous forward-reaching running-step impression. Unequal solid-leg angles and hip/torso bias give support logic while zero toe-out keeps boot orientation clean. The slow small breathing rise adds body life without a landing-style bounce. Two-sided curiosity and delayed shoulder/arm response remain calm. This is an artistic interpretation of a still reference with different proportions/camera, not a measured reconstruction. Rigid sole-edge contact and future stance entry/exit remain limitations for gameplay validation.

The [supplied GIF](references/idle_stance_reference.gif) was decoded as 81 frames / 3.38 seconds, with frame delays and SHA256 recorded in [metadata](references/metadata.json). Its visible asymmetric leg relationship and head-led observation informed v3. V2's established eight-second original timing is preserved rather than copying the GIF's timing. [User v2 screenshot](references/user_v2_front.png) records the parallel-leg comparison.

## Validation and preservation

[Clean stance orientation](clean_stance_orientation.json) measures actual forward sole-edge yaw, sideways whole-leg lean, zero front/back stagger, fixed contacts and body breathing from evaluated geometry. [Saved-source validation](validation.json) samples 3,841 poses at 1/16-frame spacing: all sole vertices remain fixed within 0.000359 mm, minimum stage clearance is about 0.400 mm, cuboid dimensions remain unchanged and sampled nonadjacent blocks do not intersect. Adjacent shoulder/hip/head joins are reviewed visually; SAT is not used to prohibit their intended overlap. Pose continuity at F1/F241 is exact; channel tangents match within 2.3e−9, and the finite vertex velocity difference across the seam is 0.118 mm/s at a 1/16-frame interval. The gentle4-second body breathing cycle has no root travel or scale tracks. Original ten Action signatures, original rest rig/weights/UV/materials/textures/lights and v2 evaluated poses match.

[Render provenance](render_provenance.json) binds the source, Action, stage/cameras and 720 PNGs. [Media checks](media_verification.json) decode every frame of all six 480-frame / 30 FPS videos against the composed source images. [Showcase checks](showcase_verification.json) cover fresh reopening, all eleven entries, original slots/ranges/FPS and source-geometry agreement after switching. [GUI playback](gui_playback.json) observes two actual wraps after reopening, then Pause and Restart. [Final preservation audit](preservation_verification.json) compares original working bytes including all v2/v1, Full Jump and Godot files. Earlier study reports remain historical evidence and are not edited.

Backups and current-hash / working-tree guards are under `.validation/idle_expressive_test_v3/`, including the previous viewer/manifest and unsaved foreground Showcase snapshots. The intersecting first pose, diagnostic renders, splayed working pass subsequent upright candidate and forward-reaching pass were archived before the latest sideways-leg/breath correction; none is a separate library animation. Registration adds only this compatible named Pending Action. The explicit in-task correction replaces only the current unapproved v3 candidate under exact old/new hash guards, preserving its backup and all ten earlier library entries. It imports no second character or rig.

## Future gameplay transition contract

- In-place, identity rig/root, unchanged rest bones, pose rotation modes, original Action slot conventions. Physics/controller owns world travel.
- Full-body Idle owns hip, legs, chest, head and arms here. Weapon-ready layers must define arm/chest/head masks and grip ownership before use; no weapon compatibility is claimed from empty-handed review.
- Do not blindly crossfade the asymmetric static soles into locomotion. Author or validate a short support transfer/replant against actual gait phase and controller direction, including the opposite lead. This does not authorize creating Walk or transition Actions now.
- Input should interrupt observation/rest promptly. Test departure from both looks and rest, including pose and velocity continuity, actual foot contacts and readable face orientation.
- Artistic approval remains separate from Godot gameplay/transition validation and measured target-phone 30 FPS. Neither is performed or claimed here. Continue one animation at a time.

## Reproduce this study

`build_test.py` starts from the preserved v2 source and refuses to overwrite its unique v3 output. `validate_test.py` operates on the saved v3 source. `render_review.py` refuses mismatched source/stage provenance before reusing PNGs; `package_review.py` requires completed provenance and passing source validation. `register_pending.py` and `update_showcase.py` record the initial Pending registration. `correct_pending_registration.py` and `update_corrected_showcase.py` apply only the explicit current-v3 sideways-leg/breath correction, refusing approved entries and preserving the backed-up candidate; all use file hashes, compatibility checks and backups. `verify_showcase.py`, `verify_gui_playback.py` and `verify_preservation.py` check the saved result. These task-local helpers do not rebuild the rig or change Godot.
