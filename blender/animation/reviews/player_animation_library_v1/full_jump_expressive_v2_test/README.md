# Full Jump Expressive v2 — lifted arms, wider flight and stronger landing

**Pending user review, 2026-10-12.** Separate `Full_Jump_Expressive_v2_Test`, preserving the original `Full_Jump_Expressive_Test`, both earlier preview files and all earlier review material.

The arms rise into an open V around the airborne peak, with a one-frame offset in their arrival/settle. At F32.5 the hand centers sit approximately **2.8 cm left / 5.1 cm right above the head**; fingertips reach **5.9 / 8.3 cm above**. The rigid full arms remain straight and visibly separated from the head.

The user's subsequent steering adds **8° of sideways opening per leg** during flight, preserving the forward/backward leg asymmetry and avoiding outward foot yaw. Sole-center spacing grows from37.7 to52.6cm at F32.5, about15cm wider. This opening eases away by F44 before touchdown; it does not widen the planted landing base.

The landing then absorbs **28mm more hip depth**:148mm total compression versus120mm, approximately23% deeper. A slightly stronger delayed pelvis/torso dip and8°/10° extra whole-arm follow-through reinforce impact. The added load builds quickly after contact, releases smoothly and does not add another rebound. Rigid soles remain anchored at the original receiving locations.

The higher arm adjustment eases in from F18, peaks around F31–34 and returns toward the original approach by F45. Takeoff, phase timing, preview arc, contacts F46/F47, deepest absorption F51, rebound F67 and recovery F93 retain their existing timing. The entire evaluated motion from F65 onward is identical to the original full jump. Duration remains **93 frames at30FPS /3.10seconds**. Root, Neck, WeaponCarrier, forearms and all unrelated animations remain unchanged.

## Quick review

- [Front / three-quarter / side at original speed](full_jump_v2_three_views_1x.mp4)
- [Three-quarter](full_jump_v2_three_quarter_1x.mp4), [front](full_jump_v2_front_1x.mp4), [side](full_jump_v2_side_1x.mp4)
- [Raised-arm peak](raised_arm_peak.jpg), [three-view phase sheet](full_jump_v2_pose_sheet.jpg)
- [Independent in-place source](full_jump_expressive_v2_review.blend)

The new review uses the existing higher **0.72m** presentation arc with unchanged timing. Its temporary parent/elevation is read from the original preview for rendering only; no trajectory is added to the reusable Action or imported into the Showcase. Camera scale widens from2.90 to3.15 and camera height rises10cm consistently across every frame/view to give the higher hands comfortable headroom. Character appearance, lighting and camera angles remain unchanged. Every output frame is freshly rendered. Original preview files are never saved by the renderer.

## Evaluation and limits

The higher open arms and wider asymmetric legs make the airborne silhouette more expansive. Unequal arm arrival retains independent articulation; the hands clear the head without an extreme overhead stretch. The stronger landing has a clearer drop and counterbalance, preserving grounded **nhúng nhúng** absorption with a single controlled rebound. Fixed sole corners and rigid-block overlap still limit how closely this can resemble a bent-knee landing.

This remains a Blender study with full rigid legs and no fabricated knees/ankles. Gameplay physics, jump interruption, weapon layers, actual Godot pose/velocity transitions and measured30FPS mobile validation remain outstanding. The arm revision does not change those readiness limits.

## Showcase and approvals

In the **same existing** `blender/animation/showcase/Animation_Showcase.blend`, select **Full_Jump_Expressive_v2_Test**, Pending. The original full jump remains immediately available as a separate Action. Play once with Loop disabled, or enable Loop to repeat for review; Restart returns to F1. The saved viewer uses in-place posing, while the rendered clip supplies temporary elevation.

The user explicitly approved **Run_Expressive_v3_Test** as the preferred run baseline in this request. Its source and Action are unchanged; original Run and Run v2 remain preserved. Only approval/preferred-baseline metadata is updated. No approval is inferred for either full-jump version.

Backups were created before changes in `.validation/full_jump_expressive_v2_test/`; central registration also creates its normal timestamped backup. The complete earlier arm-only candidate and library state are archived in `before_wider_legs_heavier_landing/`. Only this still-Pending working Action is refreshed after the user's steering. All fourteen previous Action signatures, sources and review files remain unchanged. No Godot, mesh/material/texture, rest-rig or export modification.

Evidence: [737-sample rigid geometry/support/height validation](validation.json), [camera framing](framing_verification.json), [fresh Showcase reopening/switching](showcase_verification.json), [actual one-shot/loop/pause/restart](gui_playback.json), [source-bound render provenance](render_provenance.json), [decoded videos](media_verification.json), [final preservation audit](final_verification.json).
