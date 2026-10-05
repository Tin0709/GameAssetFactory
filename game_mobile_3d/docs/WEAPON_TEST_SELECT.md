# Weapon Test Select

Run the existing `scenes/CuboidGameplayTest.tscn`. A fresh scene starts paused
with three large text cards: Pistol, M4A1 and Shotgun. Choose with 1/2/3, mouse
click, or touch. Cards use three columns in landscape and one below 850 logical
pixels. No new preview assets or inventory system are required.

Selection calls `CuboidPlayer.equip_test_weapon`, which uses the existing V2
`equip_weapon` / socket / weapon_type / Raise / recoil clips. Only one weapon
model is visible. It clears active/queued recoil, recoil gain and the firing
cooldown even when choosing the same weapon. Stance transitions retain the
existing blend and gait phase. The selector then hides and gameplay resumes.

The SceneTree is paused while selecting. Player/zombie movement, spawning,
survival time, automatic firing, projectile lifetimes, effects, pickups and
animation stop. The selection Control runs with PROCESS_MODE_ALWAYS. The root
and simulation retain their normal pausable mode. Initial enemies are created
by the unchanged SpawnDirector ready function before the pause; they do not
advance until selection. F2 ignores an existing upgrade pause or defeated run.
Level-up keys remain owned by the upgrade overlay while it is visible.

- 1 = Pistol, 2 = M4A1, 3 = Shotgun; debug switching remains during gameplay.
- F2 = reopen Weapon Test Select in debug builds; pick a weapon to resume.
- R = reset run statistics/upgrades, retaining the equipped weapon. It works
  during gameplay, defeat, level-up and weapon selection. It does not reopen
  selection. A consumed SceneTree metadata value carries the weapon through
  reload, with no saved inventory or global singleton.
- Debug HUD explicitly displays `Weapon: <name>` plus existing animation data.

## Current firing scope

All three choices are usable through the existing automatic target-acquisition
and single-projectile firing service. Pistol uses Pistol_Raise/Pistol_Recoil,
M4A1 uses LongGun_Raise/Rifle_Recoil, and Shotgun uses
Shotgun_Raise/Shotgun_Recoil. The existing shared gameplay placeholders remain
20 damage / 0.5-second interval / 8m acquisition before upgrades. No separate
rifle burst/automatic-rate profile or shotgun pellet/spread logic existed, so
this task does not add those systems or replace progression stats. Weapon
differences in this pass are model, authored stance and recoil.

## Validation (Godot 4.7.2, Mobile renderer, D3D12)

- New selection suite: 121 headless checks, 130 rendered checks, no failures.
  Includes real viewport keyboard/mouse/ScreenTouch routing, startup pause,
  F2, target acquisition, each weapon firing/recoil, LowReady/Aim, walk/run,
  strafe/backpedal, firing while moving, repeated debug changes, paused
  projectiles/effect tweens, level-up ownership, and R from both overlays.
- Existing animation matrix: 1,455 checks, no failures; target loss, repeated
  recoil, all weapons/movement directions, rigid bones, gait/stance blending,
  pause/resume. Maximum hand-marker mismatch 0.011754m (15mm tolerance).
- Existing progression suite: 85 checks, passed; upgrades, stacked level-ups,
  input routing, pause/resume, projectiles/effects and reset.
- Existing spawn suite: 65 checks, passed; pressure progression and reset.
- Selector cards fit 1280x720, 1560x720 and 720x1280. Desktop screenshots were
  reviewed. Physical phone hardware and sustained manual play were not tested.

`tests/validate_weapon_select.gd` reproduces selection validation; add
`-- --capture` with a graphical renderer to produce UI and per-weapon pose
captures. Regression results and gallery/side captures are saved with the
`weapon_select_` prefix so existing user-edited reports/images are preserved.
The unchanged regression scripts were run from temporary copies under .godot
with only report/capture destinations redirected.

## Visual observations for manual review

Front and oblique-side samples show LowReady, Aim and Aim + recoil at 80ms.
The wider animation gallery additionally samples walking poses. No asset,
scale, socket transform or authored clip was adjusted.

- Pistol: two hands crowd the small model and obscure much of the grip from
  the front. LowReady sits close to the chest; no obvious face penetration
  or reversed barrel in reviewed samples.
- M4A1: stock/receiver sit close to shoulder/chest, with support hand partly
  obscuring the model in front views. Aim is higher than LowReady; no obvious
  face penetration or gross scale/orientation problem in reviewed samples.
- Shotgun: support hand obscures part of the fore-end; LowReady is close to
  the lower chest. The stronger recoil sample remains below the face. No
  obvious gross scale/orientation problem in reviewed samples.

These are observations at the captured angles, not a guarantee of clearance
through every dynamic pose. Fine torso/hand intersections and transient
snapping still merit manual review. Contact validation does not measure mesh
intersection. Muzzles use each existing model's Muzzle_Point and firing uses
that socket position; no offset corrections were made.

## Files changed by this task

- `scripts/weapon_test_select.gd` (+ Godot UID): responsive, interactive UI.
- `scripts/gameplay_test.gd`: startup/pause/reset coordination and HUD label.
- `scripts/cuboid_player.gd`: common test equipping and firing/recoil reset.
- `scripts/animation_weapon_debug.gd`: route debug keys through common equip.
- `scripts/level_progression.gd`: route its R reset through weapon retention.
- `tests/legacy_fixture.gd`, `tests/validate_spawn.gd`: explicitly choose the
  startup pistol before older gameplay tests begin.
- `tests/validate_weapon_select.gd`: integration tests and pose captures.
- This document and `tests/weapon_select_*` JSON/PNG validation artifacts.

Pre-existing changes to Animation Runtime V2 code, docs, tests and captures
were preserved. Blender assets, GLBs, authored clips, proportions, environment,
spawn difficulty and upgrade behavior were not changed.
