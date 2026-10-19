# Crossbow Aim — literal source pose study v001

Pending Blender review; research-only, production-ineligible. User requested the actual Actions & Stuff crossbow aim pose rather than another fitted rifle pose. New Action: `Crossbow_Aim_ActionsStuff_Source_Test_v001`. Existing custom `Rifle_Aim_Hold_ActionsStyle_v001` and all earlier approved/research Actions remain unchanged.

Open the existing `blender/animation/showcase/Animation_Showcase.blend`, Animation Library → select this new entry → Play. 30 FPS, F1–108, closing sample109 excluded. The3.6s hold loop uses actual source lifetime15–18.6s; review movies show two continuous original-speed cycles. No Godot integration.

## What the pack actually does

Archive SHA256: `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`. Read the actual local `.mcpack` directly; no video or previous custom Aim supplied the pose. Exact files/aliases and dependency hashes: `source_reference.json`.

- `entity/dtr.json` selects ordinary player0, engine `geometry.humanoid.custom`.
- `animation_controllers/616f2ff7.json`: ordinary hold `njvelc.ltqtzr` runs `rrvlnm` then `dubgwy`; charged aim `knoyhk.gjhnog` runs `jawwtn` then `asxvzc` plus empty `pcbwvo`.
- `animations/f2da1071.json`: accumulated-axis Molang `this` cancellation matters. At neutral look the composed RIGHT arm is[-85,-17,0]deg and LEFT[-98,45,1]deg, body[0,12,0]deg. Source arm positions and item[-2,0,2.5]deg are retained, not merely these headline rotations. Both source main arms have unit scale; auxiliary zero-scaled skin/arrow helpers have no native counterparts.
- `q.item_is_charged && q.anim_time<0.1` jumps to1.9167s. This is an already-loaded aiming HOLD, not the1.9167s loading gesture and not a fictional rifle Ready→Aim cinematic. Source entry is evaluated and settled before recording.
- Actual0.9/1.8/3.6s breathing, roll and weight clocks remain. The charged state suppresses generic relaxed look-around under this profile; neutral look is intentional. `jawwtn` look-driven aim is evaluated at pitch/yaw0, not replaced by authored observation.

## Literal vs adapted

Full root/waist/body/head/arm/leg PRS is mapped through the established Minecraft→native hierarchy/pivot and entity-relative-head conversion. Arms remain fully straight; no support IK, socket seating, head lift, gait/foot correction, prior Aim sampling, generic idle envelope or pose optimization is used.240Hz LINEAR bake evaluates to requested native matrices with maximum error7.16e-7; source layer analytic checks ≤1.12e-16. Both closing pose and scale/forearm checks pass. These are numerical checks of this declared evaluator/retarget model, not a measured guarantee of every Bedrock rendering detail.

Rifle Stylized V2 is a preview substitute for a crossbow. The original right-hand grip POSITION is retained in its rigid arm frame. Barrel/top orientation is statically aligned to the native item frame; source `rightitem` PRS is applied in source-parent coordinates at that attachment. This is a declared rifle attachment adapter, not the original crossbow model/rest transform. `attachables/glm.json` and `ctxhqv` third-person placement were inspected; their crossbow-only geometry/offsets/particles are not misapplied to a longer rifle.

The literal left arm does NOT reach the previous approved rifle fore-end contact: the approved support anchor differs by244.4mm. This study intentionally does not pull that arm forward or redesign the source pose. Source crossbow hand spacing and a long rifle's two-hand contact layout are different. The preview is for judging the actual SOURCE BODY/ARM pose, not claiming a gameplay-ready rifle grip. Native square boot corners reach4.83mm below the floor; raw source leg motion is retained. These are explicit rig/item limitations, not silently omitted channels.

Compared with the previous custom Aim: fixed source12deg body blade replaces the authored30.34deg blade; exact asymmetric crossbow arm angles replace independent rifle fitting; neutral source head/hold replaces authored nod/attention; all prior face-clearance and shoulder-placement corrections are absent. The previous custom Action remains selectable.

## Reproduce / evidence

Raw archive extraction, samples and diagnostic caches stay outside Git. Run `python3 authoring/sample.py --pack <local .mcpack> --cache <external-cache>`, then Blender background with the immutable approved Ready v004 source file and `--python authoring/build.py -- --cache <external-cache>`. This reuses the existing audited source VM and mapper; engine conventions are recorded in `source_evaluation.json` (including hold-on-last-frame completion semantics). Rebuild only unapproved working copies; do not overwrite a later approved result. `build_validation.json`, `analytic_validation.json`, `geometry_audit.json` and save/reopen/playback/preservation reports document the result. Front/three-quarter/side movies are original speed,30FPS.
