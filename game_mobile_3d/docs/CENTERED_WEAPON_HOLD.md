# Centered runtime weapon holds

This follow-up changes only hold tuning. No meshes, clips, gameplay systems,
movement tuning, weapon stats or weapon scales were changed. Nothing was
committed or pushed. PlayerPoseLab was the main visual inspection scene.

## Final adjustments

- **Pistol:** hands close around opposite inward palm edges instead of stacking
  the gun on the forearm tops. The off-hand contact moves 1cm back and 5mm down
  in weapon-local space. The pistol is slightly more centered and lower, with
  a compact two-hand grip. Its existing 1.20 scale stays unchanged.
- **M4A1:** move the gun toward the midline and forward, lower it enough to
  clear the chin, and bring the support contact back to the underside near
  the receiver. Main hand remains the control hand. The shoulder pose moves
  forward/slightly down so rigid arms can reach without stretching. LowReady
  adds a little forward clearance, blending out toward Aim. Scale stays 1.12.
- **Shotgun:** center the gun and advance it substantially so the long stock
  no longer protrudes behind the back in reviewed views. Both hands close
  around the rear support/receiver area rather than burying the grip in an
  arm. LowReady gets extra forward clearance and shoulder reach, blended
  continuously into Aim. Scale stays 1.14. Support is deliberately nearer the
  receiver than the literal pump marker, favoring the requested closed hold.

Absolute weapon-root offsets in socket space (meters): +X moves inward from
the authored long-gun stance, +Y is barrel-forward, +Z is weapon-up:

| Weapon | X | Y | Z | Extra LowReady forward |
| --- | --- | --- | --- | --- |
| Pistol | 0.015 | 0.025 | 0.035 | 0 |
| M4A1 | 0.210 | 0.270 | -0.120 | 0.030 |
| Shotgun | 0.210 | 0.340 | 0.035 | 0.070 |

Main/support contact points use opposite arm-local X edges (-0.100 / +0.100m)
and small upper insets (0.055 / 0.055–0.065m). The existing arm rotation solver
does the inward closing. No additional gun rotation is introduced.
Arm lengths and bone scales remain unchanged. Runtime shoulder corrections
are 0 for Pistol; M4A1 10–15.5cm forward and 2cm down; Shotgun 12–19cm forward,
depending on LowReady/Aim. They move the rigid arm roots toward the front
shoulder contact rather than stretching the meshes.

## Validation and remaining overlap

- Animation matrix: **1,464 checks passed**; contact mismatch maximum
  **12.056mm**, within the existing 15mm tolerance. Locomotion cadence, target
  transitions, repeated recoil, rigid bones and switching continue to pass.
- Pose Lab: **143 rendered checks passed**, including all weapons, forced
  states, standing/moving recoil, slow playback and frozen camera interaction.
- Gameplay selector/firing regression: **124 checks passed**, including
  startup selection, repeated switching, pause/reset, HUD and muzzle origins.
- Reviewed all three weapons from side, 3/4 and top-ish lab views: Idle/Aim,
  Idle/LowReady, Walk/Aim, Run/LowReady, standing recoil and moving recoil.
  Reviewed views show no obvious severe face or forearm clipping.
- Mild palm/gun overlap remains intentionally. Long-gun stock/torso contact
  remains in LowReady, particularly Shotgun, but no large rear stock overhang
  or severe torso burial appeared in the reviewed views. This is not a
  guarantee of clearance at every dynamic instant. Physical phone untested.

## Retest

Open `scenes/PlayerPoseLab.tscn` and press **F6**. Select **1/2/3**, then
**I/W/R** for Idle/Walk/Run and **L/A** for LowReady/Aim. Press **F** for recoil.
Use **H/Q** for 0.5x/0.25x, **Space** to freeze and **.** to step. Inspect with
Side / 3/4 / Isometric buttons, right-drag orbit and wheel zoom. For long-gun
side inspection, zoom out a little so the barrel clears the control panel.

## Files changed in this follow-up

- `scripts/player_weapon_socket.gd`: contact, placement and shoulder tuning.
- `scripts/player_animation_v2.gd`: six lines applying shoulder and LowReady
  position corrections inside the existing layered pose evaluation.
- `tests/validate_animation_v2.gd`: validate bounded intentional shoulder
  correction instead of requiring the old unadjusted shoulder positions.
- This report.
- New JSON reports: `tests/center_hold_animation_validation.json`,
  `tests/center_hold_lab_rendered_validation.json`,
  `tests/center_hold_gameplay_headless_validation.json`.
- Three lab validation captures: `tests/center_hold_lab_pistol.png`,
  `tests/center_hold_lab_m4a1.png`, `tests/center_hold_lab_shotgun.png`.
- 24 inspection PNGs: `tests/center_hold_{pistol,m4a1,shotgun}_{aim_side,
  aim_quarter,aim_top,low_side,walk_quarter,run_top,fire_side,moving_fire_top}.png`.

Existing lab files and earlier capture/report artifacts are preserved. Runtime
recoil impulses, categories, weapon switching, animation clocks and gameplay
input are unchanged. Validation scripts ran from ignored .godot copies with
new output destinations; the extra inspection captures instantiate and drive
the actual PlayerPoseLab scene.
