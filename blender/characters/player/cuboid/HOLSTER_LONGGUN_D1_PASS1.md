# Holster_LongGun_V1 — D1 Pass 1

Development file: `player_cuboid_weapon_animation_dev.blend`, copied from `player_cuboid_game_export_v1.blend`. Original Run archives were appended without editing their curves. Final verification and preview setup ran through the connected Blender MCP instance.

Action: **Holster_LongGun_V1**, frames **1–18**, **24 FPS**, duration **0.708333 s**. This is a one-shot transition, not a seamless cyclic clip; Blender playback repeats it for review.

## Rig and reference

Original bone names: Root, Hips, Spine, Chest, Neck, Head, Arm.L, Arm.R, Leg.L, Leg.R.

Exactly one new helper: **Chest → WeaponCarrier**, non-deforming, length 0.18 m. No WeaponCarrier mesh weights exist. The helper is intended for future BoneAttachment3D use; a future export must include non-deforming bones. Export/runtime attachment has not been tested in this pass.

Real reference: `game_mobile_3d/assets/weapons/m4a1_v4.glb`. Its imported visual is uniformly scaled 1.12, matching the current weapon presentation. A reference mount follows WeaponCarrier with Copy Transforms. No gameplay scripts or original asset changes.

## Endpoints

Transforms below are WeaponCarrier matrices in Blender armature space (the rig object has identity transform), meters; +Z up and character forward −Y. The reference weapon follows these transforms.

READY at frame 1, matching LongGunHold_V2:

```text
[-0.997564, -0.068898, -0.010912, -0.092067]
[ 0.069756, -0.985282, -0.156053, -0.456484]
[ 0.000000, -0.156435,  0.987688,  0.968823]
[ 0.000000,  0.000000,  0.000000,  1.000000]
```

STOWED at frames 15–18, matching the D0 back reference:

```text
[ 0.951057,  0.000000,  0.309017, 0.000000]
[-0.309017,  0.000000,  0.951057, 0.300000]
[ 0.000000, -1.000000,  0.000000, 1.168750]
[ 0.000000,  0.000000,  0.000000, 1.000000]
```

## Blocking

| Frame | Beat |
|---|---|
| 1 | Ready |
| 3 | Prepare |
| 5 | Support release |
| 8 | Sweep start |
| 11 | Over shoulder |
| 13 | Back alignment |
| 15 | Stowed / handoff / release |
| 18 | Neutral exit |

Subframe offsets: Chest anticipation at 2.5; right arm/weapon pose at 3.5; left support maintained through 4.5, releasing at 5. The weapon pulls slightly inward, moves outboard for clearance, rises beside the right shoulder, turns behind the shoulder and settles onto the back. The right arm guides, releases and returns downward; the left arm trails and recovers earlier. Basic Bezier AUTO_CLAMPED handles, no detailed polish.

Sampled pose-local Euler XYZ ranges in degrees (69 quarter-frame samples):

| Bone | X | Y | Z |
|---|---:|---:|---:|
| Chest | 0…3.5 | −12…0 | 0…1 |
| Arm.L | −6.90…56.31 | −2.29…8.52 | −15.84…10.38 |
| Arm.R | −76.95…62.11 | −47.35…16.64 | −81.16…26.16 |

Chest starts at Y=−4°, so the sweep adds 8° of yaw before returning to neutral. Arm values use each bone's existing local axes, not world yaw/pitch.

Carrier armature-space position ranges in meters: X −0.7200…0.0050; Y −0.4565…0.4256; Z 0.9688…1.5700. Intermediate authored barrel elevation is 6°…90°; twist about its direction progresses from 0° to −162° to reach the stowed basis. Carrier rotation uses continuous-hemisphere quaternion keys. Euler representations wrap near ±180° and are not evidence of a physical axis flip.

## Validation and limits

- Only Chest, Arm.L, Arm.R and WeaponCarrier animated: 22 curves.
- Root keys: **0**; sampled Root travel: **0 m**.
- Hips/legs keys: **0**; scale curves: **0**.
- Spine/Neck/Head keys: **0**. Head inherits the restrained Chest movement.
- Mesh topology, vertex coordinates, groups and weights match the saved protection hashes. All original rest matrices, parent relationships, deform flags and bone lengths match the baseline.
- Ten existing actions verified unchanged, including Player_Idle and Run V1–V7_Final.
- Collision sampling at 0.25-frame intervals: no weapon intersection with the head interior or deep chest interior. Tests allow a 1 cm head boundary and 3.5 cm chest surface margin; they do not prove absence of every superficial contact or between-sample intersection.
- Gameplay, front and side key-pose renders are in `holster_d1_review`. No severe head/chest clipping was observed. Grip placement is intentionally approximate for rigid arms without elbows/hands and still needs human playback review.
- Standing preview only. Layering over Run and runtime handoff remain untested; no lower-body keys or stride-specific exit were introduced.
- No Godot export, D0/gameplay changes, Draw action, IK or added articulations.

Blender is saved with Player_Cuboid_Rig selected in Object Mode, Holster_LongGun_V1 active, frame 1, preview 1–18 at 24 FPS. Review cameras/lights are hidden only in the viewport. Press Space in the viewport to review.

Numeric validation: `holster_d1_validation.json`. Reproducible construction scripts: `setup_holster_d1.py` and `block_holster_d1.py` (the latter rebuilds only its own blocking action).
