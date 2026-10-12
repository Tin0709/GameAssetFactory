# Softer spring bounce, tiny hop and longer steps — Pending

`Walk_Snappy_Test_v1` remains a single Pending entry in the existing Animation Showcase, F1–30 at30FPS, closingF31 excluded. All older sources remain preserved. The intermediate stronger rebound and stronger hop are retained in `checkpoint_before_tiny_hop/` and `checkpoint_before_softer_load/`.

Latest steering reduces downward snap **by75%**, keeping one quarter of the stronger145mm load: **36.25mm over80ms**. The rise remains faster than the earlier even bob, with a short light top, slower settle and restrained delayed torso/shoulder/head reactions. Hip height ranges approximately623.75–724.97mm. Landing-related angular recoil is also reduced; the character keeps its rigid block proportions.

Each rebound includes a very small **15mm whole-character hop**, moving the torso, arms, head and both legs upward together. It is an explicit stylized airborne beat, rather than raising only the body above planted feet. A brief approximately28–29mm waist gap remains as requested. Both effects are intentional.

Forward/backward foot reach is **12% longer**, with unchanged0.27m contact tracks, one-second cadence and180mm piston lift measured relative to the common hop. Nominal travel for contact checks is1.1424m/s, separate from the in-place Action. The lower piston lift and advance-on-descent are retained; the rejected high kick/disappearing leg is not restored.

## Review

- [Front / three-quarter / side, original speed](walk_snappy_three_views_1x.mp4)
- [Previous lower piston versus softer spring/hop, original speed](previous_vs_rebound_1x.mp4)
- [Stronger145mm load versus softer36.25mm load, original speed](stronger_vs_softer_1x.mp4)
- [Approved Walk versus experiment, original speed](approved_vs_snappy_1x.mp4)
- [All30frames](cycle_inspection.png)
- [Rebound front](rebound_front.png), [three-quarter](rebound_three_quarter.png), [side](rebound_side.png)
- [Softer compression](compression_three_quarter.png)
- [Review source](walk_snappy_review.blend)
- [Existing central Showcase](../../../../showcase/Animation_Showcase.blend)

Reopen the existing Showcase and select `Walk_Snappy_Test_v1`, Pending. Refreshing the list alone does not replace an older cached Action in an open Blender session.

## Evaluation

The bounce has a spring-and-release rhythm with a gentler receiving dip. The hop is deliberately very low; the longer step should remain the dominant locomotion gesture. The waist gap is a stylized separated-block effect, not a new anatomical joint. Adjacent upper-leg occlusion under the shirt remains part of the rigid piston convention. The result still requires artistic approval.

## Checks and limits

961subframe samples: rigid error below0.00091mm, positive floor clearance, no nonadjacent block intersections and no unexpected unsupported interval. Both piston lifts remain approximately180.4mm after subtracting the common hop; total lifted soles peak around184.2/180.5mm. Nominal-travel support-edge drift is below0.00370mm. Waist separation peaks28.69/27.98mm, under the explicit45mm bound. The previous no-gap/no-flight criteria are superseded by this requested effect.

The hop has a120ms design window each half-cycle,17–29%of the complete cycle after each primary receiving contact; thresholded visible airborne time is approximately210ms total per one-second loop. Base64/66%support is interrupted by the hops: nominal effective support52/54%,30%double support,24%flight. Main LEFT0/RIGHT0.5 receiving phases remain, but the extra hop touchdowns are new contact events. This is a stylized hopping-walk experiment, not the approved grounded Walk.

Loop pose and channel tangents remain continuous. Raw first-order finite velocity comparison is0.006355m/s, above the old0.006guard; its legacy pass flag remains false. A second-order one-sided derivative at the same0.01-frame step gives0.00186m/s, below0.006. The more accurate estimator separates acceleration from a seam discontinuity; this must not be described as an unchanged legacy check passing.

All19other Actions and entries, rest rig, meshes, materials and older sources remain unchanged. Showcase reopening, Action/slot/view switching, inactive retention and GUI playback are checked separately. Original-speed media is decoded and visually inspected.

Root stays stationary; the visual hop is authored in body/leg pose channels. Future Godot integration must coordinate the added flight and receiving events with physics, start/stop replants, phase-aware Walk/Run blends and weapon layers. Those remain untested. No Run Snappy Action, Rifle Idle continuation, rig, Godot or production change is included.

Evidence: [motion](motion_validation.json), [registration](registration.json), [Showcase](showcase_validation.json), [appearance](appearance_validation.json), [GUI playback](gui_playback.json), [media](media_validation.json), [preservation](preservation.json).

Stop for user review.
