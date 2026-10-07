# E1 — Long-gun READY life, Pass 1

Created `LongGunReady_Loop_V1` in `player_cuboid_weapon_animation_dev.blend`.
The existing Godot `LongGunHold_V2.tres` is untouched. A matching static Blender
`LongGunHold_V2` Action was added for comparison, using the previously verified
Draw V3 endpoint / Holster V3 start pose.

## Authored motion

24 FPS, 32-frame cycle (1.333 seconds). Keys span 1–33; play 1–32, excluding the
duplicated seam pose. Seven keyed bones: Spine, Chest, Arm.R, Arm.L, Neck, Head,
WeaponCarrier. Zero Root, Hips, Leg.L, Leg.R keys; no scale tracks.

| Part | V1 blocking |
| --- | --- |
| Chest | Uneven rise, short suspension, longer release and recovery. Local pitch approximately −0.39° to +0.71° around Hold; yaw −0.16° to +0.24°; roll −0.13° to +0.09°. Combined world rotation peaks at 0.94° from the reference. |
| Spine | Smaller supporting response: pitch −0.09° to +0.18°, yaw −0.03° to +0.045°. |
| Arm.R | Shared control correction with the rifle, retaining trigger-side contact; about 0.36° peak world change. |
| Arm.L | Coordinated support correction, with different local-axis changes due to its existing pose; about 0.36° peak world change. No independent waving. |
| WeaponCarrier | Follows the chest at reduced rotational magnitude: 38% of the added torso rotation. Approximately 0.36° peak rotation, 4 mm vertical and 1.5 mm lateral peak-to-peak travel in the standalone loop. |
| Neck / Head | Neck absorbs most counterrotation; Head finishes stabilization. About 0.28° / 0.09° peak world rotation. No added vertical head bob; inherited locomotion still applies. |

The arm/rifle group shares a transform at the authored beats. Interpolation
introduces a maximum relative-transform matrix error of 0.000134; this is a
matrix-element diagnostic, not a distance or a guarantee of anatomical grip accuracy.

## Preview and visual assessment

`ready_e1_comparison.blend` opens on `E1_Run_Phase0_AB`: **Hold V2 left, Ready V1
right**. Space plays at 24 FPS. Run is sampled at cadence 1.60. The scene selector
also contains Idle, Run phases 4/8/12 (25/50/75%), and explicit GAMEPLAY_SCALE
scenes. Detail views are diagnostic. Gameplay-scale cameras match the current
Godot camera orientation and orthographic vertical size 14.5, without recreating
the arena, runtime lighting, movement, aiming or gameplay compositor.

Normal-time rendered A/B sequences are in `ready_e1_review`: Idle is 4 seconds;
Run is 6.667 seconds. APNG files preserve approximately 24 FPS millisecond timing;
GIF timing is distributed over 40/50 ms frames to approximate 24 FPS.

- **Idle:** the new Action has small, coordinated variation around the approved
  pose. Inspected renders retain the rifle silhouette and both arm roles.
- **Run:** lower-body motion remains unchanged in the preview and all source
  torso motion is retained. Relative phase was sampled for 20 seconds at each
  of four starting phases. The small Ready cycle modulates the inherited Run
  rhythm; no damping was added to hide it.
- **Gameplay readability:** the rifle remains readable in inspected frames.
  Added Ready motion is near/subpixel at gameplay distance. A meaningful
  improvement in perceived life at normal speed is **not yet visually approved**;
  still-frame inspection and numerical tests cannot establish that.
- **Remaining concern:** the full Run composition does not yet achieve the
  requested translation hierarchy. Rifle-carrier vertical travel is about
  102–103 mm peak-to-peak, compared with 75–78 mm for Chest. Hold baseline was
  98–99 mm at the carrier; V1 adds approximately 4 mm. Thus inherited locomotion
  dominates, even though the new loop itself stabilizes weapon/head rotation.

## Continuity, transitions and preservation

- Seam poses match exactly, with matched zero Bezier endpoint velocities.
- Ready neutral matches Draw V3 end and Holster V3 start within 1.2e−7 matrix
  error. Other Ready phases have small nonzero offsets and need the existing
  transition blend; arbitrary-phase runtime transitions are not integrated or
  visually approved in this authoring pass.
- 17 previous Blender Actions, original meshes/weights, rest matrices, bone
  lengths and hierarchy match pre-pass fingerprints. The runtime Hold resource
  hash also matches. All gameplay files remain untouched.
- Zero inset head/deep-chest weapon intersections in the sampled M4A1 overlays;
  no major clipping in inspected rendered poses. This does not claim all weapons,
  all aim directions, or every runtime composition is collision-free.
- Lower-body overlay matrix error is at most 1.2e−7 (floating-point tolerance).

`PREVIEW_ONLY_*` Actions exist only in the separate comparison file. They bake
composed motion for convenient playback; **Run is not baked into
LongGunReady_Loop_V1**. The primary development file contains the clean upper-body
Action. A pre-E1 `.blend` backup and `ready_e1_protection.json` are retained.

Stopped after V1 blocking. No V2/V3, runtime integration, or approved-system edits.
Numerical details: `ready_e1_validation.json`.
