# Springier rebound and longer steps — Pending

The existing `Walk_Snappy_Test_v1` entry now uses this experiment. F1–30 at 30 FPS, closing F31 excluded. The previous lower-piston version remains saved unchanged in `../piston_v004/`.

The new rhythm is **load → spring upward → brief light top → settle**. It replaces the earlier more even rise and fall. Contact compression increases from 110 to 145 mm over the same 80 ms. Hip height range increases from 130 to 195 mm (+50%). The upward rebound reaches its peak at 220 ms after contact, rather than 380 ms; the rise from deepest compression takes 140 ms rather than 300 ms. The top eases over before the slower descent. Restrained torso recoil and delayed shoulder/head reactions help the motion read as a spring response rather than a uniform vertical translation. All rigid body dimensions remain unchanged.

The user's additional steering lengthens forward/backward foot reach by 12%, while keeping the 0.27 m contact tracks and 180 mm piston lift. Cadence remains one second per complete alternating cycle. Nominal travel for contact checks rises correspondingly from 1.02 to 1.1424 m/s; this travel is separate from the in-place Action.

## Review

- [Front / three-quarter / side, original speed](walk_snappy_three_views_1x.mp4)
- [Previous lower piston versus springier rebound, original speed](previous_vs_rebound_1x.mp4)
- [Approved Walk versus experiment, original speed](approved_vs_snappy_1x.mp4)
- [All 30 frames](cycle_inspection.png)
- [Rebound front](rebound_front.png), [three-quarter](rebound_three_quarter.png), [side](rebound_side.png)
- [Compression three-quarter](compression_three_quarter.png)
- [Review source](walk_snappy_review.blend)
- [Existing central Showcase](../../../../showcase/Animation_Showcase.blend)

Reopen the existing Showcase and select `Walk_Snappy_Test_v1`, Pending. Refreshing the list alone does not replace an older Action already cached in an open Blender session.

## Evaluation

The rebound is faster and more buoyant, with a stronger contrast between soft receiving and upward release. The foot paths retain their modest vertical pull followed by advancing descent; there is no return to the rejected high hip kick or stomach-height disappearing leg. The increased front/back reach creates a clearer stride without widening the tracks. A brief approximately 28–29 mm gap above the planted leg is intentional, following the user's reference. This is a stylized separated-block effect; it is not anatomical deformation or a new joint. Adjacent waist/upper-leg occlusion during recovery remains part of the rigid piston convention.

## Validation and limits

961 subframe samples preserve rigid lengths (maximum error 0.00136 mm), positive floor clearance, continuous support and no nonadjacent block intersections. Both lifted soles still peak at approximately 180.4 mm. Nominal-travel support-edge drift is below 0.00370 mm. Waist separation is bounded by an explicit 45 mm limit for this requested effect; measured maxima are 28.69 mm left and 27.98 mm right. The previous no-gap criterion is intentionally superseded for this experiment.

Loop pose error is below 0.00002 mm and channel tangent discrepancy below 0.000002. The raw first-order finite velocity comparison is 0.006025 m/s, slightly above its previous 0.006 guard. That measurement includes opposite-sign acceleration on either side of the seam. It remains reported, with its legacy pass flag **false**. A second-order one-sided derivative at the same 0.01-frame step gives 0.00358 m/s and passes the 0.006 continuity limit. This changes the estimator, not the numeric limit; it must not be described as an unchanged legacy check passing.

All 19 other Actions and manifest entries remain exact. Meshes, materials, rest rig and older review sources are preserved. The existing 20-entry Showcase is verified through fresh reopening, Action/slot/view switching, inactive retention and GUI playback/wrap/restart. Original-speed media is decoded and inspected.

Shared LEFT receiving phase 0 and RIGHT phase 0.5, 64/66% support and 30% double support/no flight remain. Root stays stationary. Stronger rebound and deliberate waist separation need artistic review, and future runtime start/stop replants, phase-aware Walk/Run blending and weapon layers remain untested. No Running Action, Rifle Idle continuation, Godot or production edit is included.

Evidence: [motion](motion_validation.json), [registration](registration.json), [Showcase](showcase_validation.json), [appearance](appearance_validation.json), [GUI playback](gui_playback.json), [media](media_validation.json), [preservation](preservation.json).

Stop for user review.
