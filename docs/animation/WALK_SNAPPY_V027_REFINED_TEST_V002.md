# V027 refinement v002 — softer steps, spring body, zero leg gap

2026-10-14 · **Pending** · `Walk_Snappy_V027_Refined_Test_v002`.

This combines the user's three requests: soften the heavy steps, make the up/down body response feel like jelly, and preview zero distance between the legs. It starts from V027 refinement v001. Original V027, v001 and all25 prior Actions remain unchanged and selectable. This is a combined artistic preview, superseding the earlier timing-only isolation scope.

[Previous v001 versus v002, original speed](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v002/v001_vs_v002_1x.mp4) · [Front / three-quarter / side](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v002/refinement_three_views_1x.mp4) · [Side A/B](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v002/side_AB_1x.mp4) · [Actual reference / v001 / v002](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v002/reference_v001_v002_1x.mp4).

Every clip contains six continuous alternating model steps,63 frames at30 FPS, no holds or replay pauses. Reference frames30–92 remain at recorded1x speed. Native20-frame reference versus21-frame model cadence drift is retained. Diagnostic stills align referenceF30+i to modelF1+1.05i; only the stills normalize time.

## Softer steps

Inspection showed near-zero speed at actual landing already; the larger visual drop occurs just after the lifted-leg crest. A swing-only22ms Gaussian height filter rounds that turnover. A bounded12ms phase lead spreads lowering into the earlier part of swing, so the final approach does not need to rush. A sin(pi*x)^4 blend keeps the existing support/release/contact intervals intact. The peak lift is slightly lower, disclosed below; no whole-animation speed increase is used.

| Lowest-sole measurement | v001 L / R | v002 L / R |
|---|---|---|
| Peak lift |370.2 /366.8mm |339.8 /333.7mm |
| Peak downward speed |3.662 /3.827m/s |3.180 /3.250m/s |
| Final100ms RMS vertical speed |1.840 /2.048m/s |1.611 /1.748m/s |

## Springy body and close head follow

An original receive/load/recover/settle drive is passed through a periodic damped spring response (8Hz natural frequency, damping0.58), delayed20ms. Its difference from the preferred V027 hip curve is softly bounded to12mm. This gives compression, rebound and settle variation without a large new hip excursion or a disconnected torso. The actual body range is0.6804–0.8210m. One bounce per step and the700ms walking stride remain.

The head receives an additional smooth0–8mm lift based on35ms of body history, retaining a close attachment. Torso/arm/head orientation curves stay copied from v001; shoulders and arms inherit the spring body translation. Feet are rebaked in world space so they do not rise with the new hip response. The jelly quality comes from timing and follow-through; all blocks retain their dimensions, with no squash/stretch or rig changes.

## Zero leg spacing preview

Leg blocks are225mm wide. Their nominal tracks are now225mm apart, giving **zero lateral gap**, with separate centres. The old sideways leg roll/yaw caused intersections on the narrow tracks. For this requested preview only, both legs keep their original forward pitch and move in parallel sagittal planes; lateral roll/yaw is removed. The body still keeps its original angular sway.

Y compensation preserves planted sole pivots after removing lateral tilt. Fixed early/late pivot identities blend only while airborne, avoiding discontinuous corner switching. This is an intentional spatial/orientation exception for the zero-gap experiment; the full3D leg path is not claimed unchanged. General cadence, forward swing timing, contact framesF1/F11.5, in-place nominal travel1.59936m/s and playbackF1–21/closing22 are retained. Zero gap is an artistic preview, not approved production spacing.

![Step and body curves](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v002/timing_curves.png)

## Review assessment

The rounded crest and lower downward speed aim to make each step lighter; the bounded rebound and delayed head add a softer body response. The narrow front silhouette is a substantial aesthetic change and needs the user's judgement. Technical validation does not establish that it feels satisfying or matches Actions & Stuff. The local deep research's uncertainty limits remain: exact reference contacts,3D rig paths and interpolation cannot be recovered from these recordings. No proprietary assets/keyframes were copied.

[Aligned early phases](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v002/phase_aligned_1.jpg) · [Aligned later phases](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v002/phase_aligned_2.jpg) · [Every native side frame, part1](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v002/native30_side_1.jpg) · [part2](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v002/native30_side_2.jpg) · [part3](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v002/native30_side_3.jpg).

## Verification and limits

- 1345 geometry samples: no floor penetration/nonadjacent overlaps. Ground-anchor drift0.00724mm at nominal travel; rigid error0.000252mm; projected inner-leg gap error0.000060mm. Existing stylized hop/airborne timing is retained, not a grounded-walk claim.
- 449 paired checks verify authored foot targets/body response, original forward pitch and all unaffected curve signatures. The waist separation reaches73.03mm, below the unchanged75mm historical limit but still visible. Head/chest clearance stays positive at3.91mm.
- Loop pose error0.000160mm; second-order velocity seam0.003513m/s passes0.006 at the historical0.01-frame interval. Raw first-order0.011671m/s remains separately reported. Internal receiving derivative probe0.007436m/s is also reported rather than hidden as an artistic pass.
- All25 previous Actions/manifest entries and6415 protected existing files remain exact, including research, prior reviews, approved animations and Godot. Rig rest, geometry, weights, UVs, materials/images remain exact.26 entries pass91 checks; actual GUI loops twice, pauses/restarts and retains inactive Actions after reopening. Nine H264 videos decode567 frames at30FPS.

Source SHA:fd251d5ded1945d8bb563bd60f0443256dbc5c5c98f76e8e6f569733ecdb2de1. Action SHA:24c09273498ba144438cfd11d0ef174cb06aaa010000a9780cbd41c9e0f2a722. Machine-readable reports accompany this review. Earlier leg-only/failed geometry candidates were kept in the validation workspace; none was registered.

No Godot/gameplay/production, approved Walk/Run, rig or paused Rifle Idle changes. No Run Action or separate Foot Recovery Path experiment. Runtime speed/turn/start-stop/weapon blending remains untested. **Stopped for artistic review.**
