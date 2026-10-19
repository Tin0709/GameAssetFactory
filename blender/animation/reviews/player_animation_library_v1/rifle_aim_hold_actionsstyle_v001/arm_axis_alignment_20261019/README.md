# Rifle barrel / right-arm alignment — Pending

Select **Rifle_Aim_Hold_ActionsStyle_v001** in the existing **Animation_Showcase.blend → N → Animation Library**. The same Pending entry is updated; no additional Action, Showcase or Godot scene is created.

The barrel previously differed about20.975degrees from the right complete-arm axis. It now points along that unchanged arm axis in3D, rotating around the same right-hand grip. A2degree rotation about the barrel axis clears the square head while retaining that alignment. The left whole arm is refitted to support the reoriented rifle. Both complete arms remain straight.

Only14 location/quaternion curves on `WeaponCarrier` and `UpperArm.L` changed. The other112 curves are exact copies, including the right arm, head, torso, lower body, all scales and forearm articulation. There is no elbow, limb-length, mesh, material, rest-rig or rifle-model edit. The original grip pivot,3.6second loop,240Hz bake and0.9/1.8/3.6second source clocks remain.

This is a rifle/rig alignment adjustment of the preceding shoulder-seated Pending study, not a newly discovered Actions & Stuff controller. The immutable charged-crossbow reconstruction, verified pack SHA, player source/controllers (`entity/dtr.json`, `animations/f2da1071.json`, `animation_controllers/616f2ff7.json`; `njvelc` + `knoyhk`) and all approved Actions remain unchanged. The previous full pose is preserved in [shoulder_seated_pose_20261019](../shoulder_seated_pose_20261019/README.md), linked by `previous_pending_source`. Source-derived content remains research-only/nonproduction. No Godot integration.

Review at original speed: [3/4 movie,30FPS](aim_reference_30fps_1x.mp4), [top before/after](comparison_top.png), [side still](aim_side.png). The matched top images use the same camera and F85. The saved viewport opens from above for this alignment review; existing Front/3/4/Side camera datablocks are unchanged. Playable F1–108, closing109; the movie shows two continuous cycles (216frames/7.2seconds).

The native square head/tall rifle still limit exact optical ADS; this correction makes the barrel parallel to the right arm without claiming perfect eye/sight coincidence. Head/collar seating and inherited source boot-corner floor seating are unchanged. Both fitted palm anchors are stable relative to the weapon, with the left support's small sampled surface gap quantified in `geometry_validation.json`.

For a scratch rebuild, copy `authoring/` outside Git, open the pinned preceding `.blend` named in `baseline_entry.json`, and run `build.py` using `--python-exit-code 1`. Outputs go beside the script. `static_pose.json` defines the fitted matrices; parameters record the contact adapters. Open the generated source and run `validate.py`. Do not register or overwrite approved sources during rebuilding. Raw fitting/geometry caches stay outside Git.

Save/reopen, native playback, geometry/alignment, curve-preservation and media reports accompany the study. All88 other native Actions, existing assets and Godot remain intact. Existing `.blend` LFS tracking is reused; no history migration, force push, tracking-pattern change or manual commit/push is performed.

Validated217half-frame poses: barrel/arm angular error≤0.000011degrees; right grip error≤0.56µm. Left support sampled gap≤10.10mm; head/rifle gap≥29.43mm. No unwanted intersections; exact loop pose. Saved/reopened selectors and two native playback loops pass;30FPS movie decodes216frames. All88 other Actions and6857prior protected files, including2007Godot files, remain exact.
