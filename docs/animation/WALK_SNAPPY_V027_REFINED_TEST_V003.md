# V027 refinement v003 — natural stance and clearer leg snap

2026-10-14 · **Pending artistic review** · `Walk_Snappy_V027_Refined_Test_v003`.

The user rejected zero leg spacing and requested the earlier stance with a slightly smaller gap, plus further leg-snap refinement. This separate test restores the pre-zero leg roll/yaw from v001 while retaining the softer vertical landing and spring body/head response of v002. Original V027 and all26 previous Actions/entries stay unchanged; v002 is preserved as a rejected spacing experiment, not deleted or promoted.

## Original-speed review

[Previous zero-gap v002 versus v003](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/v002_vs_v003_1x.mp4) · [Front / three-quarter / side](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/refinement_three_views_1x.mp4) · [Side A/B](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/side_AB_1x.mp4) · [Actual reference / v002 / v003](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/reference_v002_v003_1x.mp4).

Six continuous alternating model steps,63 frames at30 FPS /2.1 seconds. No holds or replay pauses. The reference remains actual WalkingF30–92 at recorded1x speed; its20-frame versus model21-frame cycle drifts naturally. Static phase sheets map referenceF30+i to modelF1+1.05i; only these stills normalize time. v002 was freshly rendered read-only. The unchanged [pre-zero v001 review](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v001/README.md) remains available to compare its wider natural stance.

## Restored stance

- Original natural leg roll/yaw is restored from v001 at the new swing phase. The parallel-plane restriction used for zero gap is removed.
- Nominal leg tracks are267mm apart, versus270mm before the zero-gap test.225mm block width gives a **42mm nominal gap**, versus45mm before; the visible gap varies with pose and rotation.
- A smooth recovery-only outward correction of up to4mm prevents the legs pinching together at passing. It is zero throughout planted support and at the next contact. This is a small lateral-path exception, not a claim that the full3D recovery path is identical.
- Clearance probes rejected265mm tracks after detecting0.68mm of leg overlap.267mm retains1.31mm minimum separating-axis clearance in the337-sample probe; the full geometry review also finds no nonadjacent overlaps. The stance reduction stays deliberately small to preserve natural leg angles without clipping.

## Leg snap and placement

An additional10ms phase lead is introduced only after vertical support release, using sin(pi*x)^4 across airborne recovery. It rises smoothly through the exchange and disappears at the original next contact. This creates a faster forward swing followed by more time to brake into placement. Contact frames, full-stride duration and nominal travel speed remain unchanged; the full animation is not sped up.

Spatial leg matrices come from the natural v001 path at the new phase. Their lowest sole height is then restored to the **actual v002 height at the current time**, preserving its softer lift/landing and intentional hop. Leg local transforms are rebaked under the unchanged animated hip parent. **Every non-leg curve and evaluated body/head/arm world pose is exact against v002** across449 paired checks. No body/head adjustment hides the leg change.

| Measured event after opposite receiving | v002 L / R | v003 L / R |
|---|---|---|
| Sole centre passes hip sagittally |176.56 /185.94ms |168.75 /178.12ms |
| Peak forward sole speed |6.177 /6.661m/s |7.061 /7.663m/s |
| Peak lift |339.8 /333.7mm |339.8 /333.7mm |
| Peak downward speed |3.180 /3.250m/s |3.180 /3.250m/s |
| Contact / stride |350ms /700ms |unchanged |

Measurements use the same1.5625ms grid. Passing is a diagnostic silhouette landmark, not certified anatomical contact. The10ms clock lead is our authored experiment, not recovered Oreville keyframe timing. Local deep research supports fast/slow spacing contrasts and repeated compact/exchange pose families; exact source contacts,3D paths and interpolation remain uncertain.

![Timing comparison; body/head and vertical foot curves overlap](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/timing_curves.png)

## Artistic evaluation and limits

The restored angles recover the natural front silhouette. The leg moves through the body earlier with a more decisive swing while the established gentle vertical arrival stays intact. This is a provisional improvement in exchange clarity, not a claim of matching the satisfying full Actions & Stuff rhythm. The higher peak swing speed can still read as too abrupt at30FPS; use the1x comparison to judge it. All native frames of one stride are in [side strip1](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/native30_side_1.jpg), [strip2](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/native30_side_2.jpg) and [strip3](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/native30_side_3.jpg); phase sheets are [early](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/phase_aligned_1.jpg) and [late](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v003/phase_aligned_2.jpg).

## Verification and preservation

- 1345 geometry samples: no floor penetration/nonadjacent intersections; ground-anchor drift0.00270mm at nominal travel; rigid-distance error0.000252mm. Airborne/support masks match v002. Existing stylized flight is retained, not a grounded-walk claim.
- Lowest-sole height error versus v002 is0.000268mm; non-leg world-matrix difference is zero. Time-mapped natural leg orientation matches its v001 source. Known waist separation remains up to71.71mm, under the unchanged75mm historical limit but still visible. Head/chest clearance is3.91mm.
- Loop pose error0.000160mm; second-order velocity seam0.004220m/s passes0.006 at the historical0.01-frame interval. Raw first-order0.011671m/s remains a legacy failure. Internal receiving probe0.007436m/s is identical to v002 and separately recorded as an inherited failure; no threshold was relaxed.
- All26 older Actions/entries and6490 protected existing files remain exact, including approved animations, earlier reviews, research and Godot. Rig rest, geometry, UVs, weights, materials/images remain exact.27 entries pass94 switching/slot/timing/prop/view/inactive-reopen checks; actual GUI loops twice, pauses and restarts. Nine H264 videos decode567frames at30FPS.

Source SHA:0b6ac0eb6399d382dedbf2292e6091a2b6c98ed9f7d99f01725a0f00bdd8fca6. Action SHA:1980fb7da676154c20f426d1ab43001da50315c37f10d9369424b0efcc73d960. Machine-readable reports accompany this review.

No Godot/gameplay/production or rig changes, no Run Action or separate Foot Recovery Path study, and Rifle Idle stays paused. Runtime speed/turning/start-stop/weapon blends remain untested. **Stopped for artistic review.**
