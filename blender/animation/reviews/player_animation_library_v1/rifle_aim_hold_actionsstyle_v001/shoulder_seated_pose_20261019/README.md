# Compact shoulder-seated rifle Aim/Hold — Pending

Open the existing `Animation_Showcase.blend`, **N → Animation Library → Rifle_Aim_Hold_ActionsStyle_v001**. This updates the same Pending entry; no extra Action or Showcase is created. Godot and approved gameplay are unchanged.

The user's09:50 screenshot exposed an error in the previous fit: the right arm root was allowed to slide far forward down the body. A surface-contact check alone did not enforce an anatomical shoulder. That iteration remains archived in `../focused_aim_pose_20261019/` and was not approved.

## Correction

The current fit constrains arm roots near the source anatomical shoulder locations, instead of allowing the holding set to reach forward for face clearance. The rifle grip is about277mm farther back along worldY than the archived overextended pose. Its height is1.28m, with24.1degree yaw and2degree upward pitch. Torso lean is reduced to3.1degrees; the head nods about11degrees and cants toward the rifle about9degrees. These static photo/rifle fits are authored adaptations, not literal proprietary crossbow angles.

Both complete arms remain straight and rigid. The existing right-hand grip point is unchanged. The left fitted palm supports the fore-end, and the two painted hand blocks intentionally touch with tiny seating. The head follows the upper-body breathing delta with30% of the original head micro-motion overlaid, keeping the aiming pose coordinated. A28mm head-base seating offset fits the canted square head to the collar; actual mesh contact, rather than a floating gap, is checked throughout the cycle. There are no elbows, scale, limb-length, rig, mesh, material or rifle-model changes.

## Source and limits

The unchanged source is `Crossbow_Aim_ActionsStuff_Source_Test_v001`, from the verified Actions & Stuff1.12 pack (SHA256 `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`). Relevant files: `entity/dtr.json`, `animations/f2da1071.json`, `animation_controllers/616f2ff7.json`. Crossbow base `njvelc.ltqtzr` layers `rrvlnm` then `dubgwy`; charged hold `knoyhk.gjhnog` layers `jawwtn` then `asxvzc` (`pcbwvo` is empty). See the [immutable crossbow study](../../crossbow_aim_actionsstuff_source_v001/README.md) for the literal source reconstruction.

The original0.9/1.8/3.6second clocks supply body breathing, weight motion and holding rhythm. Root/Hips/legs remain source-exact. Head mounting to the chest, reduced head micro-motion, static arm fit and long-rifle attachment are declared adaptations to the user photo and this13-bone character. No generic idle curves or replacement source timing are introduced.

The native large cube head and tall M4 stock/handle still limit exact eye-to-sight alignment: calibration right-eye/axis offset is about166mm. This is a compact held aim, not a claim of perfect optical ADS; the native rifle has no added scope or remodeled stock. The source character's existing4.83mm boot-corner floor seating remains. This neutral charged Hold loop does not add a gameplay transition; prior Ready→Aim→Hold→Ready sources remain in the manifest's `previous_pending_source` chain. Source-derived material remains research-only/nonproduction.

## Review

30FPS at original speed, F1–108 with closing109;240Hz bake. Each movie contains two continuous3.6second cycles. The side/back before/after uses exactly the same camera and F85 so the former forward extension remains visible for comparison.

- [Before / after at the back-side angle](comparison.png)
- [Front three-quarter](aim_reference_30fps_1x.mp4)
- [Back three-quarter](aim_back_30fps_1x.mp4)
- [Front](aim_front_30fps_1x.mp4)
- [Side](aim_side_30fps_1x.mp4)

Compact source reconstruction files are in `authoring/`: copy them to scratch, open the immutable crossbow `.blend` and run `build.py` with `--python-exit-code 1`, then open its generated source and run `validate.py`. Output goes beside the script. The fitted matrices/parameters are sufficient; raw geometry and optimization caches remain outside Git. Do not register or overwrite approved sources during a rebuild.

Geometry, save/reopen, native playback, media decoding and preservation reports accompany the study. Earlier sources remain available. The canonical Showcase imports only the replacement Pending Action, keeping its other88 Actions and existing assets exact. Existing `.blend` LFS patterns are reused; no tracking-pattern changes, history rewrite, manual commit or push are performed.

Validated217 half-frame poses: head/rifle sampled surface gap≥61.47mm; left support sampled gap≤10.87mm; shoulder gap≤0.00mm; head/collar seating≤14.79mm. Intentional hand seating about0.80mm. No unwanted intersections; exact loop pose and source Root/Hips/leg parity. All88 other native Actions and the prior protected files (including2007 Godot files) remain exact. Saved/reopened selection and two native playback loops pass; all four movies decode216frames at30FPS.
