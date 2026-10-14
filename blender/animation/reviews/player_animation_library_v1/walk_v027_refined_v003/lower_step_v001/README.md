# Same v003 — half-height recovery and stronger body snap

2026-10-14 · **Pending artistic review** · `Walk_Snappy_V027_Refined_Test_v003` updated **in place**.

The user requested half the current leg lift and an even stronger downward body snap. The Action name and index26 remain;27 Showcase entries are retained. The [pre-edit v003 source](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/body_snap_v001/walk_v027_refined_review.blend) and its review media remain unchanged. No v004 or duplicate Action was added.

## Original-speed review

[Before / after same v003](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/lower_step_v001/before_vs_after_1x.mp4) · [Front / three-quarter / side](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/lower_step_v001/lower_step_three_views_1x.mp4) · [Side A/B](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/lower_step_v001/side_AB_1x.mp4) · [Actual reference / before / after](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/lower_step_v001/reference_before_after_1x.mp4).

Six continuous alternating model steps,63 frames at30 FPS /2.1seconds, with no holds or replay pauses. Reference WalkingF30–92 stays at recorded1x speed; its20-frame versus model21-frame cadence drift is visible. Static sheets map referenceF30+i to modelF1+1.05i for diagnostic phase alignment only. The current pre-edit v003 was freshly rendered read-only.

## Half leg lift

During each leg's recovery, its **lowest-sole clearance above the0.4mm floor margin** is multiplied by0.5. Fore/aft/lateral motion, leg pitch/roll/yaw and rig dimensions remain unchanged. This translates the whole rigid leg down; it does not shorten or scale it.

| Measured lowest-sole peak | Before | Updated | Clearance multiplier |
|---|---:|---:|---:|
| Left |339.807mm |170.103mm |0.500000 |
| Right |333.734mm |167.067mm |0.500000 |

The planted/support part and existing common hop remain intact. Primary contactsF1/F11.5 and the authored support/release phases stay unchanged; the small thresholded airborne count changes near contact because recovery clearance is lower, rather than because extra landing keys were inserted. No floor penetration is introduced. Nominal stance remains267mm tracks /42mm gap, stride700ms, playbackF1–21/closing22 excluded,30FPS and1.59936m/s diagnostic travel.

## Stronger receiving snap and elastic recovery

“Even more” is interpreted for this preview as **another25% increase in contact-to-trough compression depth**: 52.3308→65.4135mm, verified on both steps. Contact height and the approximately75ms load timing are retained. This is a deeper receiving dip, not a claim of25% more downward speed throughout the whole stride.

The compact C2/quintic load pulse releases by135ms, followed by a small1.5mm added overshoot at175ms settling by230ms. The inherited spring response remains underneath. Hip range changes0.669895–0.823291m to0.656813–0.824670m; peak upward hip speed changes2.6042→3.0109m/s. Global peak downward speed remains1.2881m/s in the unchanged later fall.

Torso/shoulders/arms inherit the deeper hip response. A bounded±2mm head reaction follows35ms of the added pulse's history, with zero added lift at contact. Angular curves, straight block geometry and proportions remain exact. No squash/stretch or rig rebuild. Leg local translations are rebaked against the new hip height so the horizontal foot path stays stable while recovery height changes.

![Half recovery height and stronger body response](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/lower_step_v001/timing_curves.png)

## Review assessment and verification

The recovery silhouette is visibly lower, with less of the raised leg entering the stomach area. The deeper receiving dip and stronger rise aim for a clearer jelly-like body response. Judge the motion at1x; technical checks alone do not establish an Actions & Stuff match. The existing separated-block waist seam and common-hop style remain artistic limitations. No proprietary keys/assets were copied, and the prior research's contact/rig/camera uncertainties still apply.

[Early aligned phases](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/lower_step_v001/phase_aligned_1.jpg) · [Later phases](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/lower_step_v001/phase_aligned_2.jpg) · [Native30FPS side strip1](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/lower_step_v001/native30_side_1.jpg) · [strip2](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/lower_step_v001/native30_side_2.jpg) · [strip3](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/lower_step_v001/native30_side_3.jpg).

- 1345 geometry samples: no floor penetration/nonadjacent overlaps; ground-anchor drift0.00288mm at nominal travel; rigid-distance error0.000252mm. Waist separation reaches73.73mm, under the unchanged75mm historical limit but still visible; head/chest clearance stays positive at3.18mm.
- 449 paired checks verify the half-height targets, unchanged leg horizontal matrices/orientation, body response and unaffected curves. Lowest-sole target error0.000164mm; leg target-matrix component error0.000000179. Both lift and compression multipliers are independently checked on actual evaluated motion.
- Loop pose error0.000133mm; second-order velocity seam0.004489m/s passes0.006 at historical0.01-frame spacing. Raw first-order0.011671m/s and internal receiving probe0.007083m/s remain separately recorded. No thresholds were relaxed.
- Same27 entries pass94 switching/slot/timing/prop/view/inactive-reopen checks; actual GUI loops twice, pauses and restarts. All26 other Actions/entries and6640 protected existing files remain exact, including previous v003 revisions, older reviews, approved animations, research and Godot. Rig rest, geometry, UVs, weights, materials/images unchanged. Nine H264 videos decode567frames at30FPS.

Source SHA:d68ba6c7961851c7eb358d4e614e8006eae75db20903f8bc0b82d26a9c791ea5. Action SHA:30dd70cd05dfe918ac17f52d8ccc847014d8c40a8176c0e316fdb3c3b2267034. Previous v003 Action SHA:0dbeafec0e7a3e1679798ddad7a7fdcc0c6dd93fdac1578d75d63e7eb472296a. Machine-readable reports accompany the review.

No Godot/gameplay/production changes, no new Action or Run/Foot Recovery Path study; Rifle Idle stays paused. Runtime speed/turn/start-stop/weapon blends remain untested. **Stopped for artistic review.**
