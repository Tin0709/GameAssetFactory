# Same v003 — stronger receiving compression and elastic rebound

2026-10-14 · **Pending artistic review** · `Walk_Snappy_V027_Refined_Test_v003` updated **in place**.

The user explicitly requested the same Action, with25% more downward body snap and a jelly-like rebound. The Showcase still has27 entries and the same v003 name/index26. No v004 or duplicate Action was added. The [previous v003 source](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/walk_v027_refined_review.blend) and all of its reviews remain unchanged; the current entry points to this saved revision.

## Original-speed review

[Before / after same v003](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/body_snap_v001/before_vs_after_1x.mp4) · [Front / three-quarter / side](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/body_snap_v001/body_snap_three_views_1x.mp4) · [Side A/B](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/body_snap_v001/side_AB_1x.mp4) · [Actual reference / before / after](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/body_snap_v001/reference_before_after_1x.mp4).

Each clip contains six uninterrupted alternating model steps,63 frames at30 FPS /2.1seconds. No holds or replay pauses. Reference WalkingF30–92 stays at recorded1x speed, with native20-frame versus model21-frame cadence drift retained. Static phase sheets align referenceF30+i to modelF1+1.05i; only these stills normalize time. The pre-edit v003 was freshly rendered read-only.

## What25% means here

The requested increase is applied to **contact-to-trough compression depth**, not the entire walk's playback speed or all vertical motion. Contact height remains0.722226m. Both receiving steps deepen from41.8646mm to52.3308mm: measured multiplier **1.250000** for both left and right receiving events. The load trough remains about75.0ms after contact.

A compact quintic/C2 compression pulse increases the downward receiving dip, then releases smoothly by135ms. A small2.5mm positive overshoot peaks at175ms and settles by230ms, flowing into the existing spring rhythm. Position, velocity and acceleration remain continuous at pulse boundaries. This is an event-shaped addition to the existing performance, not a generic new sine bounce or whole-animation speed increase.

The measured hip minimum changes0.680362→0.669895m; its maximum changes0.821037→0.823291m. Peak upward hip speed changes2.2788→2.6042m/s. Global peak downward speed remains1.2881m/s because that maximum occurs in the unchanged later fall; no claim is made that every downward velocity increased25%.

Torso, shoulders and arms follow the deeper hip pulse through the existing hierarchy. The head receives a close0–4mm additional lift driven by35ms of the new pulse's history, giving slight lag into rebound. Existing angular curves and rigid-block dimensions remain exact; no squash/stretch, new rig controls or proportion edits.

## Legs, spacing and speed preserved

All leg world matrices are rebaked against the moving hip parent and remain exact to float precision:449 paired checks show maximum matrix-component error0.000000238, rotation difference0.000000rad, and lowest-sole difference0.000238mm. The current leg snap, softer landing, natural roll/yaw,267mm tracks /42mm nominal gap, receiving framesF1/F11.5 and intentional hop/airborne intervals are retained.

Playback remainsF1–21 /30 FPS, closingF22 excluded,700ms per stride and nominal travel1.59936m/s. Leg local translation curves change only to compensate for the new body height; the evaluated feet and legs do not inherit extra bounce. All unaffected curves, including body/arm/head/leg rotations, retain exact signatures.

![Stronger receiving dip and recovery; unchanged sole trajectory](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/body_snap_v001/timing_curves.png)

## Review judgement and verification

The new dip makes weight acceptance more pronounced, and the quicker release plus small overshoot aims for a springier jelly feel while keeping the feet stable. This remains an artistic preview; passing checks does not establish that it feels satisfying or matches Actions & Stuff. Known separated-block waist styling remains visible. The reference/research uncertainty limits are unchanged and no proprietary assets or keys were copied.

[Aligned early phases](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/body_snap_v001/phase_aligned_1.jpg) · [Aligned later phases](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/body_snap_v001/phase_aligned_2.jpg) · [Native30FPS side strip1](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/body_snap_v001/native30_side_1.jpg) · [strip2](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/body_snap_v001/native30_side_2.jpg) · [strip3](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/body_snap_v001/native30_side_3.jpg).

- 1345 geometry samples find no floor penetration/nonadjacent intersections; rigid error0.000252mm; nominal-travel ground-anchor drift0.00282mm. Waist separation reaches72.95mm, below the unchanged75mm historical limit but still visible; head/chest gap stays positive at4.63mm.
- Loop pose error0.000133mm and second-order velocity seam0.004220m/s pass the historical0.006 guard at0.01-frame spacing. Raw first-order0.011671m/s remains a separately reported legacy failure; the internal receiving probe0.007083m/s is also retained separately. No threshold was relaxed.
- Same27 entries pass94 switching/timing/slot/prop/view/inactive-reopen checks; actual GUI playback loops twice, pauses and restarts. The current v003 is still Pending.
- All26 other Actions/manifest entries and6565 protected existing files remain exact, including the pre-edit v003 source/reviews, earlier versions, approved animations, research and Godot. Rig rest/geometry/UVs/weights/materials/images are unchanged. Nine H264 videos decode567frames at30FPS.

Source SHA:890d2fd97de5be46c7438cf7f6dfb1ab01f32265e6ebf38e156a13ac17edb34e. Action SHA:0dbeafec0e7a3e1679798ddad7a7fdcc0c6dd93fdac1578d75d63e7eb472296a. Previous v003 Action SHA:1980fb7da676154c20f426d1ab43001da50315c37f10d9369424b0efcc73d960. Machine-readable proofs accompany this review.

No Godot/gameplay/production edits, no new Action/Run/Foot Recovery Path study; Rifle Idle stays paused. Runtime speed/turn/start-stop/weapon blends remain untested. **Stopped for artistic review.**
