# Walk Expressive Test

**Pending user review.** Independent `Walk_Expressive_Test` in the existing [Animation Showcase](../../../showcase/Animation_Showcase.blend). The latest **Idle_Expressive_Test_v3 is explicitly approved and the preferred idle baseline**, confirmed2026-10-11. Earlier idle versions and all previous Actions remain preserved.

Playback **F1–36 at30FPS**, closing keyF37 excluded: **1.2seconds per loop**, left contactF1 and right contactF19. Turn on Loop playback. Original Blender5.2 slot `OBRUN_Test_Rig` is preserved even though the study actor is named `WEX_Test_Rig`. Source [walk_expressive_review.blend](walk_expressive_review.blend) contains an unchanged rest rig, packed character textures and original review stage.

## Review

- [Three-quarter walk, original speed](walk_three_quarter_1x.mp4).
- [Front walk, original speed](walk_front_1x.mp4).
- [Side walk, original speed](walk_side_1x.mp4).
- [Three views together, original speed](walk_three_views_1x.mp4).
- [Traveling side contact diagnostic,0.9m/s](walk_contact_travel_1x.mp4).
- [Contact, receiving, passing and release poses](walk_pose_sheet.jpg).
- [Approved idle versus walk posture](idle_walk_posture.jpg).
- [Previous versus quieter, closer-footed refinement](hip_response_comparison_1x.mp4).

The four in-place videos show four complete loops, without a duplicated closing frame. The contact diagnostic shows three loops at nominal travel speed, using temporary object/camera translation and floor markers only. No world travel is keyed in the character Action; no extra character or presentation Action is imported into the Showcase. The traveling review is an authored-speed diagnostic, not Godot gameplay footage.

## Motion and evaluation

The latest refinement halves the sideways body movement relative to the previous delivered walk: hip side travel is now 38 mm total (was 76 mm), and the dynamic lateral roll of the pelvis, spine and chest is halved. Pelvic yaw remains ±3.6°. The 36 mm local fore/aft waist response and 22 mm vertical receiving range remain intact, preserving the diagonal weight transfer without the stronger side-to-side wiggle. Both walking tracks move another 10 mm inward, from 0.29 m to 0.27 m apart. Whole-leg lateral lean is eased to −0.25°/+0.375° for thigh clearance, and toe angles stay 5°. Straight arms still oppose the legs, and head world rotation remains below 2° on each axis. This is a quieter, closer-footed continuation of the same Pending walk, with the previous complete version preserved for comparison.

Each leg supports for60%/62% of the cycle, giving22% total double support and no flight. Unequal recovery clearance and arm timing provide restrained asymmetry. The planted rigid boot rocks through its lowest sole edge/corner; its backward speed relative to the actor matches **0.9m/s**, with1.08m of controller travel per cycle. Measured planted drift is below0.002mm, with no floor penetration or nonadjacent body intersections in the saved-source checks. Whole-leg pose offsets retain the existing hip-overlap convention; cuboid dimensions and rig are unchanged.

The result is a relaxed walking foundation, distinctly quieter than approved Run. The principal limit remains the rigid whole-leg setup: support uses corner/edge rocking and bounded hip overlap rather than knee folding or ankle articulation. A constant-speed flat-floor test cannot establish turning, slopes, speed scaling, start/stop behavior or armed gait quality.

## Idle and future transition contract

This is a repeating moving gait, not a baked idle→walk→idle sequence. It shares the idle posture language without copying the look-around routine into locomotion. The approved idle's fixed asymmetric15° toe-out stance is~0.40m wide; walking uses5° toe-out and0.27m tracks so feet travel cleanly. Entry/exit must transfer support and replant into the destination stance; do not blend two planted feet laterally and call that contact-safe. The idle's stronger four-second breathing is not copied at full amplitude onto every walking step.

F1 is left receiving/right supporting; F19 is the opposite. Future Walk↔Run blending should align these support events, compare both lead feet and handle Run's release/flight phases. Nominal speed and phase must survive repeated controller updates. Prompt input interruption, short taps, acceleration/braking, both idle attention directions and re-entry at arbitrary times require actual Godot validation in a separately authorized task.

The Action owns all baked local bone locations/rotations as a **full-body absolute pose**, not an additive layer. Root/object transforms remain identity; the controller owns world translation. Weapon animation needs a deliberate Chest/shoulder/arm mask and reference pose while hips/legs retain support. No export, controller change, Run refinement or measured phone performance is claimed. Target remains30FPS; Blender approval is not production readiness.

## Safety and verification

Backups and working-tree/hash guards are under `.validation/walk_expressive_test/`, including the original viewer, manifest, metadata, approved-idle authoring copy and foreground session. The successful first walk candidate, complete review material, central Showcase and metadata were additionally backed up in `before_hip_response/` before this user-requested refinement. The hip-sway candidate was separately archived in `before_diagonal_response/` before adding the fore/aft component; the complete diagonal candidate and native renders are archived in `before_narrow_tracks/` before the stance adjustment. The intermediate0.32m source/central file and partial renders are additionally preserved in `before_half_gap/`; the subsequent0.29m stance is now backed up in `before_quieter_sway/`, with its complete native reviews, source and central library, before this0.27m/half-sway refinement. Only the still-Pending Walk Action was revised; the eleven earlier library Actions remain unchanged. The first contact candidate is archived separately; its subframe sole-rocking interpolation was corrected before final registration. All eleven previous Action signatures and approved idle source bytes are preserved. Only idle approval metadata changes; Walk starts Pending.

[Saved-source validation](validation.json) checks1153subframe poses, rigid dimensions, sole contacts at nominal speed, floor clearance, intersections, hip seams, camera bounds, original appearance/rig/weights and loop pose/velocity. [Phase poses](phase_pose_verification.json) verify arm opposition and steady gaze. [Current refinement comparison](quieter_refinement_verification.json) measures the halved lateral hip and world body-roll ranges against the immediately preceding complete walk, the10mm inward shift per planted track and unchanged fore/aft, vertical and support timing. Older refinement scripts/reports describe historical stages preserved in backups and are not current delivery evidence. [Showcase checks](showcase_verification.json), [interactive playback](gui_playback.json), [media checks](media_verification.json) and [final preservation audit](final_verification.json) bind results to the saved source/Action hashes. The loop's channel tangents match; finite vertex velocity is also checked with a stated0.01frame numerical step.

Use the existing Showcase N-panel to select the Action, reset/play/pause and switch views. Registration follows [ANIMATION_WORKFLOW.md](../../../../../docs/animation/ANIMATION_WORKFLOW.md); every future revision must have its own name and begin Pending. Do not edit this Action after approval.
