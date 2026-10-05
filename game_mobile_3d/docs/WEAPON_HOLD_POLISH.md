# Runtime weapon hold polish

This pass changes only runtime attachment/pose tuning and relevant validation.
Weapon GLBs, player proportions, animation library and authored clips remain
unchanged. No external assets were used. No reference screenshots were present
in this chat turn; the written hand-edge direction guided the tuning.

## Final per-weapon tuning

Offsets are meters in authored socket space: +Y barrel-forward, +Z weapon-up.
The imported weapon's existing +90 degree X coordinate conversion is retained;
there is no extra per-weapon rotation. Uniform scale pivots around Grip_Point.

| Weapon | Uniform scale | Forward offset | Up offset | Support contact refinement (weapon-local) |
| --- | --- | --- | --- | --- |
| Pistol | 1.20 (+20%) | 0.035 | 0.065 | Existing two-hand support marker |
| M4A1 | 1.12 (+12%) | 0.015 | 0.075 | 0.018 lower, 0.025 rearward |
| Shotgun | 1.14 (+14%) | 0.020 | 0.070 | 0.015 lower, 0.020 rearward |

The cuboid arms are 0.225m wide/deep and 0.675m long. Their previous contact
was at the arm volume center, 0.605m along the arm. New palm contact Z values
are 0.090m (main) and 0.100m (support), close to the 0.1125m outer surface.
Per-weapon along-arm values accommodate the existing rigid poses without
stretching: main 0.610/0.587/0.590m; support 0.616/0.617/0.623m.

The sole Animation V2 pose writer rotates each rigid arm about its unchanged
shoulder toward the scaled grip/support contact. It applies this after shared
lean and authored recoil, so hands follow the final weapon pose while retaining
authored twist. Final corrected upper poses blend from the captured pose during
weapon switching, once, without accumulating offsets. Arm length/scale and
shoulder positions are unchanged. WeaponSocket recoil/category selection remains
the existing implementation. Muzzle_Point inherits the same root transform as
the visible mesh, so firing needs no separate muzzle correction.

## Visual review

Reviewed six poses per weapon at isometric and closer angles: idle, walking,
running in LowReady, standing Aim, standing fire and running fire. Additional
front/side captures show an 80ms recoil sample.

- Pistol: slide/barrel now reads above the hand edge. Main grip and off-hand
  support are cleaner; the magazine no longer appears centered through the
  forearm in reviewed views. Mild grip/palm overlap remains intentionally.
  The two large cuboid hands still obscure some grip detail in front views.
- M4A1: receiver/barrel is exposed above the arm, main hand remains at the
  grip, and support sits beneath the forward region. Mild hand/fore-end overlap
  remains. The stock is close to the shoulder/neck in LowReady; no obvious
  face penetration was seen, but this area remains tight in projected views.
- Shotgun: barrel and pump read more clearly along the hand edge; main grip
  and underside support are cleaner. Mild pump/support-hand overlap remains.
  The long stock still projects over the upper torso in some angles, without
  obvious deep arm burial or face penetration in the reviewed samples.

Rigid cuboid arms have no elbow/finger articulation, so this is a cleaner
stylized hold, not a fully articulated grip. Contact error tests do not measure
mesh penetration. Sampled views do not guarantee clearance at every instant.

## Validation

Godot 4.7.2, Mobile renderer / D3D12 on the existing desktop:

- Animation matrix: 1,464 checks passed. Main/support outer-edge contacts
  remain within the unchanged 15mm tolerance (maximum 13.341mm), across
  all weapons, LowReady/Aim, idle/walk/run, strafe/backpedal and recoil.
  Added checks for per-weapon scale and unchanged shoulder positions.
- Weapon selector/firing: 124 headless and 133 rendered checks passed.
  Startup pause, mouse/touch/keyboard selection, F2 reopen, debug switching,
  R retention, HUD, level-up pause/resume and transformed muzzle origins pass.
- Rendered inspection includes standing and moving recoil. Physical mobile
  hardware and sustained manual play were not tested.

The integration suites were run from temporary .godot copies with output names
redirected to `tests/weapon_hold_*`, preserving earlier validation artifacts.
Run `tests/capture_weapon_hold.gd` with a graphical renderer to reproduce the
six-pose isometric/close inspections. The extra front/side screenshots come
from the existing selector capture suite with the same output redirection.

## Files changed in this pass

- `scripts/player_weapon_socket.gd`: per-weapon scale, grip-pivot offset,
  support contacts and outer-palm tuning constants.
- `scripts/player_animation_v2.gd`: cached arm/socket indices, rigid-arm
  contact correction and blending of final corrected upper poses.
- `tests/validate_animation_v2.gd`: validate the intentional outer-edge
  contact targets, scaling and shoulder preservation.
- `tests/validate_weapon_select.gd`: verify projectile birth at the actual
  transformed muzzle for each selected weapon.
- `tests/capture_weapon_hold.gd`: focused six-pose inspection capture.
- This report and new `tests/weapon_hold_*` JSON/PNG results.

Existing pending changes from previous tasks remain preserved. No gameplay,
spawn, upgrade, input, HUD or selector implementation was refactored.
