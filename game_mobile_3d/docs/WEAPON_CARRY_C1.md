# Weapon carry C1

One shared `WeaponHold` animation is layered over the approved Idle/Run in the
existing V2 pose compositor. The imported AnimationPlayer supplies clip data;
V2 remains the sole skeleton pose writer. A second AnimationTree writer would
conflict with this architecture, so this uses a cached animation pose with an
explicit three-bone filter, not a new runtime or procedural grip solver.

## Hierarchy and existing weapons

`Actors/Player/Visual/Model/Player_Cuboid_Rig/Skeleton3D/WeaponAttachment`
is a BoneAttachment3D attached to the existing non-deforming `WeaponSocket`
bone under Chest. Thus the weapon follows the visual skeleton, not an independent
gameplay-root transform. Root -> Hips -> Spine -> Chest remains unchanged.

The existing weapon instances are Pistol, M4A1 and Shotgun. Their local transforms
are unchanged: X rotation pi/2; uniform scales 1.20 / 1.12 / 1.14; offsets
(0.015, 0.025, 0.035), (0.21, 0.27, -0.12), (0.21, 0.34, 0.035).
Muzzle_Point and existing contact markers remain intact.

## Pose and state

`assets/characters/WeaponHold.tres` contains only position/rotation tracks for
Arm.L, Arm.R and WeaponSocket. No scale tracks or lower-body tracks exist.
The generator `tools/create_generic_weapon_hold.gd` samples the existing
LongGun_Raise once offline and creates a single shared low-ready pose with a
small front-shoulder clearance. There are no per-weapon carry clips.

The layer blends in/out over 0.13 seconds. Arms and the socket inherit Chest's
global movement while their local carry pose stays controlled. Chest, Spine,
Neck, Head, Root, Hips and both legs are untouched by this filter. The existing
authored torso rhythm therefore remains present over both Idle and Run.

Main CuboidPlayer opts in with `generic_weapon_carry = true`. Other scenes retain
their existing behavior. Debug key 0 unequips/hides the gun and disables its
existing firing gate; 1/2/3 equips Pistol/M4A1/Shotgun and restores the prior gate.
Switching never resets the Run clock. The previous procedural palm-to-grip
solver is skipped in this mode; no new IK, raycasts or retargeting are added.

## Validation

- C1: 84 checks passed headless and rendered with Mobile/D3D12.
- Existing movement/weapon suite: 798 checks passed.
- Authored locomotion regression: 36 checks passed, with carry disabled during
  baseline pose comparisons. Authored position error approximately 4e-9 m,
  root translation 0, scale error 0, and continuous circular Run clock retained.
- All three weapons tested over Idle/Run, armed start/stop, direction changes,
  moving switches and moving fire. Four uninterrupted Run cycles additionally
  confirm inherited arm motion and zero animated Root travel.
- A same-time layer-on/layer-off comparison verifies Root/Hips/Legs/Spine/Chest/
  Neck/Head poses are identical. One live skeleton remains.
- Runtime Run scale 1.60, Run speed 6.25 m/s, Walk speed 4.25 m/s and original
  locomotion blend remain unchanged. Fire still uses the original <=3 m/s gate;
  moving fire was tested at the existing combat speed 2.6 m/s, not full-speed Run.
- Both production/test Blender files and the imported character GLB retain
  their prior SHA-256 hashes. No mesh, skinning, rest pose or imported clip edits.

Gameplay-camera screenshots in `tests/carry_c1_*.png` cover all weapons and
armed/unarmed Idle/Run. Additional close views use only temporary test-camera
zoom; the gameplay scene camera is unchanged. Sampled views show no distracting
weapon/head or weapon/chest intersection. Minor shoulder/arm overlap and imperfect
grip contact remain acceptable prototype limitations; the compact Pistol is
partially obscured by the shared two-arm pose. These are visual samples rather
than an exhaustive geometric collision proof.

Final rendered validation and the live preview launch have no engine errors or
warnings. Earlier sandboxed runs could not create the user shader-cache directory;
the normal-access rendered run resolves that environmental warning.

Runtime cost is one cached static pose, a scalar weight and three position/
quaternion blends within the existing compositor. No duplicate skeleton or
additional solver exists. Mobile-device performance has not been measured.

## Files

Runtime changes: `scripts/player_animation_v2.gd`,
`scripts/animation_weapon_debug.gd`, `scenes/characters/CuboidPlayer.tscn`.
New pose/generator/test: `assets/characters/WeaponHold.tres`,
`tools/create_generic_weapon_hold.gd`, `tests/validate_weapon_carry_c1.gd`.
Baseline test updated: `tests/validate_blocky_v7_integration.gd`.
Generated evidence: C1 JSON/screenshots/logs and refreshed regression JSON reports.

Stop at C1. Next step is human review of shared carry silhouette and transitions
at the actual gameplay camera before deciding on any further animation work.
No new recoil, shoot, reload, aiming IK or Blender changes were made.
