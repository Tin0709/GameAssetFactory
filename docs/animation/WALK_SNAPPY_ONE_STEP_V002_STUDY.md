# Snappy One-Step Study v002: four-step rhythm review

2026-10-14 — **Pending artistic review.** Action Walk_Snappy_OneStep_Study_v002, separate from v001 and all older Actions. Registered in the same [Animation Showcase](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/showcase/Animation_Showcase.blend), now23 selectable entries. This finite four-step probe is a temporary review sequence, not a production Walk or gameplay replacement.

## Watch at original speed

[Uninterrupted reference / V028 / v002, four alternating model steps](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v002/reference_v028_v002_four_steps_1x.mp4).

[Front / three-quarter / side, four uninterrupted steps](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v002/v002_four_steps_three_views_1x.mp4).

[Actual reference / V028 / v001 / v002 first-step comparison](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v002/reference_v028_v001_v002_first_step_1x.mp4).

All moving clips are 30FPS and1x, with **no inserted holds, replay pauses, fades or time normalization**. V002 contacts are F1/11.5/22/32.5/43: L/R/L/R/L,0/.35/.7/1.05/1.4 seconds. The43-frame video includes the final contact sample and displays for1.433 seconds; the actual first-to-last motion span is1.4 seconds. V001's original13-frame one-shot is freshly rendered unchanged and compared separately; it has no authored four-step continuation, so it is not artificially repeated, mirrored or bridged.

## Specific coordination changes

The reference's F30–40 step remains the primary timing observation: receiving-like placement, quick lowering aroundF31–33, brisk recovery/exchangeF33–35, readable upper arcF35–38 and approach to the next placementF39–40. The uncut review uses actual original framesF30–72, with its natural camera and cadence. All304 original frames were decoded again and source SHA verified. Contact is a candidate with±1frame uncertainty; reference camera motion, perspective and cap rotation are not treated as joint curves. Artistic delays below are original hypotheses, not recovered Oreville rig/interpolation settings.

| Mechanic | v001 | v002 |
|---|---|---|
| Step time |350ms |350ms, unchanged |
| Hip excursion |0.665–0.745m,80mm |0.665–0.745m,80mm, unchanged |
| Lowest hip after contact |59.9ms |54.7ms |
| Peak upward hip velocity |1.64m/s |1.98m/s; redistributed spacing, same height |
| Raised-foot crest |144.8ms |125.0ms; same290mm piston target |
| Right sole passes hips |163.0ms |155.2ms |
| Peak forward sole speed |8.47m/s |9.33m/s; V028 is9.83m/s |
| Head loading pitch follows chest loading pitch |9.9ms |34.9ms |
| Head recovery pitch trough |175.0ms |209.9ms |

**Leg recovery and placement:** support releases at65ms after the opposite contact, as in v001. The whole rigid leg reaches its lift crest earlier, then advances through a concentrated fast phase. Forward travel is distributed across adjacent frames, followed by deliberate braking and a shallow arrival. The final swing height reaches zero with zero vertical velocity/acceleration at contact. The first spacing draft concentrated too much travel into a single frame; that draft is preserved outside the active library, and the final path broadens the forward burst rather than increasing playback speed. Small outward swing clearance stays bounded18mm and returns to the original270mm landing tracks.

**Weight impulse:** a55ms load is followed by a strong early recovery impulse, then a rounded approach to the crest and a readable upper arc. The crest is later than v001's, but the largest upward spacing occurs earlier within the recovery. This contrast provides the snap without adding height, flight or a generic sine wave. Hip pitch loads with support; torso unfolds and partially counters the hip yaw. No lateral root/hip drift was added.

**Follow-through:** chest reaction remains25ms behind its event; shoulder translation and whole-arm swing now use45ms history (previous20/25ms). Head pitch uses60ms rather than35ms; head height/roll/yaw use45/55/55ms history. The head therefore continues its loaded pose after the torso begins unfolding, and releases later after rebound. Secondary head-height response stays smoothly bounded±6mm using tanh, avoiding a hard clipping corner. Elbows stay straight and block geometry does not deform.

**Continuous alternation:** body height/pitch repeat per receiving event; roll, yaw and opposing arm curves reverse across alternating supports with matched endpoint values and derivatives. Both feet use a consistent0.7-second stride,0.415-second support window and moving stance anchors. The one-shot's unequal fore/aft endpoints were regularized for consecutive contacts at the same cadence and nominal1.59936m/s travel. Nominal step travel remains0.559776m; the in-place Action does not move the Root. The sequence starts already walking, with secondary motion inherited from the preceding phase; this is not an Idle-to-Walk start.

## Phase comparison and visual evaluation

Static sheets align actual referenceF30+i to modelF1+1.05i, for eleven first-step phases. Reference step length is10frames/.333s versus models10.5frames/.350s. These subframe samples are diagnostic only; native-speed video phases are allowed to drift. All crops are constant over time and comparable in character height. The reference only supplies the front-facing angle; model side views assess our own silhouettes and clearances.

![Receiving, loading and swing](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v002/normalized_first_step_1.jpg)

![Braking and placement](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v002/normalized_first_step_2.jpg)

![Four continuous steps from front, three-quarter and side](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v002/four_step_consecutive_views.jpg)

![Actual model timing and spacing curves](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v002/timing_spacing_comparison.png)

The rendered phases show an earlier raised-leg exchange and a more ordered hip→chest→head response. The uninterrupted sequence exposes whether that order reads as a satisfying repeated rhythm. It retains a walking support phase throughout; it does not gain energy by adding flight. The model still differs from the reference in its receiving silhouette, rigid-leg recovery shape and restricted shoulder/head looseness. The front reference also holds an item. These are reasons to review the feel at1x, not reasons to equate a numeric pass with a match. Artistic success remains Pending.

## Grounding, rig limits and verification

The rig, proportions, meshes, materials and existing rigid-leg convention are unchanged. Same80mm hip range and290mm piston target as v001; no common-leg hop or scale animation. With no knee, a planted rigid leg cannot produce a deep crouch and large rise while keeping a perfectly attached hip. The existing sliding upper-leg occlusion and a maximum60.2mm waist separation remain visible review tradeoffs. This does not claim a seamless anatomical hip attachment.

- **2689 subframe samples:** no unsupported intervals, floor penetration or nonadjacent block overlaps. Minimum floor clearance0.400mm; rigid-distance error0.0002mm; nominal-travel sole-anchor drift0.0018mm; head/chest separating-axis gap at least33.8mm. Adjacent torso/leg seating is deliberately the existing piston treatment.
- Three internal receiving boundaries are continuous; maximum second-order vertex-velocity difference0.00345m/s under the historical0.006 guard at0.01frame spacing. A smaller50microsecond numerical probe produced0.010–0.018m/s; raw results remain recorded separately, and were not called passing. The selected estimator uses the historical step size rather than amplifying float noise. No posed reset is inserted between steps.
- 82 Showcase checks passed: all23 entries switch correctly with timing, slots, props and views; all23 Actions survive inactive save/reopen. Actual separate GUI playback advances through the four-step sequence, stops atF43 and supports restart/play/pause. It is registered as a finite review, Loop off by default, without CYCLES modifiers.
- All22 previous Action signatures and manifest entries remain exact, including Pending v001/V028 and approved animations. Both comparison sources were freshly rendered read-only. Original reference SHA remains2b4930b899230814606fc3f6ce341e6966b82a91d6a5d4a665e3057938beab0c.
- Eight H264 videos decode at30FPS,284frames total. Protected-file audit preserves6041 existing files outside the five authorized central library/status updates, including all v001/V028 sources/reviews and Godot.

Source SHA256:e5c60a13b89e3fcdf8b273860a2cc52ee4c0b62ad286d639cfda8ca6942e5cb1. Action SHA256:4b4a853133f89e1afb05a79e34557d013d4f9100678ad53eb3130f2ffec31c6f. Validation reports and measured timing data are saved beside this README.

This full-body absolute study is not an additive gameplay layer. Future full-cycle selection still requires artistic review, support-aware starts/stops, weapon masks and engine transition validation. Approved Walk/Run/Ready, paused Rifle Idle and all Godot work remain untouched. No Run Snappy Action or production Walk was created. **Stopped here for artistic feedback.**
