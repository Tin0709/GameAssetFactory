# Snappy Walking: One-Step Motion Study v001

2026-10-13 — **Pending artistic review.** Separate Action: Walk_Snappy_OneStep_Study_v001. V028 and all older Actions remain unchanged. This is a short receiving-to-opposite-placement experiment, not a proposed full walk cycle. No Godot or rig edits.

[Watch actual reference / V028 / one-step study at original speed](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v001/reference_v028_study_review_1x.mp4). Each moving segment runs at 30 FPS and 1x. Six repetitions include explicitly labelled 0.5-second still endpoint pauses and hard replay cuts. These pauses are for reading; the restart is not a loop seam.

[Uncut 13-frame comparison, without pauses](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v001/reference_v028_study_uncut_1x.mp4) · [Front / three-quarter / side, 1x with labelled replay pauses](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v001/one_step_three_views_review_1x.mp4).

## What was observed in the actual reference

Decoded all 304 frames of [Walking_Reference_Original.mp4](C:/Users/ADMIN/Desktop/SnappyMotionReferences/Snappy_Walk_Run_Reference_Analysis/SourceVideos/Walking_Reference_Original.mp4), 246×356, 30 FPS. Selected the clear repeating F30–40 step, 1.000–1.333 seconds; F40–50 confirms the alternating pattern. Frame numbers here are zero-based. Reference SHA256: 2b4930b899230814606fc3f6ce341e6966b82a91d6a5d4a665e3057938beab0c.

| Reference frames | Step phase | Visible evidence and interpretation |
|---|---|---|
| 30–31 | 0–0.1 | Extended receiving-like leg silhouette, followed by lowering. Contact is a candidate, not a proven sole-ground event. |
| 31–33 | 0.1–0.3 | Chest/logo and cap descend quickly. Chest low near F32; cap stays low into F33. The relative timing suggests a small upper-body delay. |
| 33–35 | 0.3–0.5 | Large upward image spacing over a few frames and a compact leg exchange. The lively feeling comes from this rapid change after loading. |
| 35–38 | 0.5–0.8 | Upper silhouette remains readable while the opposite leg extends. Head tilt and arms continue moving rather than locking at the recovery pose. |
| 39–40 | 0.9–1.0 | Approach to the next receiving-like placement; the alternating pattern continues. |

Cap lowering is about 20 pixels over the early loading frames. Both raw tracking and approximate far-background camera correction retain the short low-to-rise episode. Camera translation, perspective, cap rotation and logo visibility prevent treating pixels as joint heights or physical acceleration. Contact timing is uncertain by about one source frame (33 ms). Shoulder orientation and independent head tilt are visible; exact hip rotations, rig structure, interpolation, forces and foot locks are not recoverable from this front recording. The reference holds an item asymmetrically; our unarmed study uses its own arm poses. No proprietary assets or keyframe data were extracted.

![Actual reference with cap/logo landmarks and motion phases](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v001/reference_one_step_annotated.jpg)

## Three findings against V028

1. **The torso does too little of the receiving work.** V028 changes height strongly, but chest pitch spans roughly -2.2° to 7.9° during this step. Its head is relatively stable above that motion. The study makes the chest fold into loading and release to a mild backward recovery: -2.5° to 12.5°, with independently delayed head pitch.
2. **V028 is already fast at the leg, so extra speed is not the missing ingredient.** Its measured peak forward sole speed is about 9.83 m/s. The study peaks at 8.47 m/s. The change is earlier release, lift-before-advance, and a defined braking interval paired with body recovery. It is not a claim of a higher peak swing speed.
3. **The secondary parts need a designed response to the same event.** V028 retains earlier arm-local curves; its body and limb peaks do not read as one impulse. The study explicitly loads the hip/chest, releases the torso, reverses the arms on their own event curve and lets the head continue after the chest starts recovering.

## What the experiment authors

Primary step time stays **0.35 seconds**, V028's half-stride cadence. Reference F30–40 spans 0.333 seconds. Nominal controller travel stays 1.59936 m/s, represented diagnostically; the Action remains in place and does not move the root. The Action samples F1–13 at 30 FPS: 0.4 seconds from first to last sample, consisting of one step plus a 50 ms receiving tail. Its encoded 13-frame clip displays for 0.433 seconds. It ends during the next load, not in a settled idle.

| Study time | Authored event |
|---|---|
| 0–60 ms | Left receiving, rapid hip compression and controlled forward chest fold. |
| 65–110 ms | Right foot releases, whole rigid leg lifts before committing to advance. |
| 85–145 ms | Hip recovery accelerates, chest unfolds, swing advances decisively. |
| 145–270 ms | Raised leg passes and reaches; upper-body arc remains readable. |
| 270–350 ms | Foot brakes and descends into placement with zero vertical arrival velocity. |
| 350–400 ms | Right receiving tail; body begins the next compression, then playback stops. |

The pelvis pitches with loading and turns toward the changing support; chest yaw partially counters it. There is no lateral root/hip drift and no repeating generic sinusoidal body curve. Torso, arms and head have original event-based quintic Hermite curves with continuous velocity/acceleration at their design knots. Chest delay is 25 ms, arm delay 25 ms, head pitch delay 35 ms; shoulder translation and head height response are small and bounded. These delays are artistic hypotheses, not recovered Oreville settings. Block limbs retain their original lengths and straight elbows.

The right swing moves outward at most 18 mm while airborne to clear the opposite rigid leg, then returns to its original landing track. Ground anchors retain the existing nominal speed; this is clearance, not a wider stance or added side wiggle.

## Diagnostic comparison and artistic evaluation

The normalized sheets map reference F30–40 to model F1–11.5. Static comparison samples the models at subframes; it uses actual reference frames without synthesized in-betweens. No moving review video has been time normalized. Reference and model clips retain their slightly different natural cadences. Front crops use constant framing across time, at comparable character height; no per-frame tracking removes the bounce. A matching side reference does not exist, so side renders assess our silhouettes and attachments only.

![Receiving, loading and exchange at matching step phases](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v001/normalized_step_frames_1.jpg)

![Upper arc, braking and opposite receiving at matching step phases](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v001/normalized_step_frames_2.jpg)

![Timing and spacing comparison](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_one_step_v001/timing_spacing_comparison.png)

**Evaluation:** The torso fold/release and arm reversal are more readable from the side and three-quarter view. Earlier leg exchange and explicit braking provide more contrast between fast transit and readable placement. The recovery aims to feel like one coordinated impulse rather than independent height and leg oscillations. However, the study's head rises earlier than the reference's cap trace and has a small second upper arc. Its grounded hip excursion is smaller and the reference starts higher at its receiving candidate. The front reference has a broader, looser shoulder/head rhythm. This study does **not** establish a stylistic match; the original-speed comparison is the artistic decision point.

## Rig constraint and the deliberate tradeoff

The existing straight leg is about 0.675 m long, with no knee. A planted foot cannot follow a deep crouch and high torso rise while keeping a clean attached hip, unless the rigid leg penetrates the torso, opens a waist gap, or leaves the ground. V028's common leg hop raises both feet during its recovery. This study instead keeps left support grounded throughout and limits hip travel to **0.665–0.745 m (80 mm)**, rather than V028's 150 mm. It does not increase bounce height or overall playback speed.

Whole-leg lift still requires the existing sliding rigid-leg treatment; the upper leg can be concealed inside the torso during recovery. The measured waist separation reaches **61.7 mm**, visible at the crest. A knee-folded recovery, fully attached deep compression, or the same large rise with perfect planted support cannot be reproduced cleanly with this rig. No new bones, scaling, proportions or mesh changes were made. Whether the smaller grounded impulse is appealing enough is unresolved and belongs to this review.

## Preservation and verification

- All **21 existing Action signatures and manifest entries** remain exact; V028 source SHA256 remains 2da9e6335be107568e9696fa39fd68d1516083f42bccade44f247bc5823329b8. V028 was freshly rendered read-only for this comparison.
- **22 selectable entries** now exist in the same [Animation Showcase](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/showcase/Animation_Showcase.blend). The new study is Pending; Rifle Ready approval and other statuses are unchanged. No new Run Action or full walk cycle was made.
- **769 subframe geometry samples:** grounded support throughout, minimum floor clearance 0.400 mm, maximum virtual ground-anchor drift 0.0012 mm, rigid-distance error 0.0003 mm; no nonadjacent block overlaps. Head/chest separating-axis clearance stays above 26.1 mm. Adjacent leg/torso seating is intentionally the existing sliding treatment, not a claim of zero adjacent penetration.
- 79 selection/timing/slot/prop/view/retention checks passed, including inactive save/reopen. Separate actual GUI playback advanced through F1–13, stopped at the end, restarted, played and paused correctly. This one-shot is explicitly not seamless; no loop-continuity claim is made.
- Character/rifle meshes, UVs, weights, materials, image resources and rest rig remain exact. Seven H264 review videos decode at 30 FPS, 401 frames total.
- Protected-file audit preserves 5968 existing files outside the five authorized central library/status updates, including Godot and all V028 review assets. Machine-readable evidence is in this review folder.

This is an absolute full-body study, not an additive layer. Any later full-cycle authoring must test both receiving sides and the loop. Future Godot integration still needs phase-aware planted-foot handoffs, starts/stops and weapon masks; no runtime changes or transition certification are implied.

**Stopped here for user feedback.** No full revised walking cycle, Run Action or gameplay replacement follows automatically.
