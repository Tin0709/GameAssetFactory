# Player movement and weapon behavior pass

This pass changes player-only spring tuning, the shot profiles, movement eligibility,
short muzzle flashes, and Pose Lab presentation. Runtime V2, imported hold poses,
weapon socket offsets/scales, recoil clips, free walk/run speeds, zombie animation,
progression, SpawnDirector, environment and enemy stats are preserved. No commit or push.

## Player bounce

| Parameter | Previous | Production default |
|---|---:|---:|
| Walk contact velocity impulse | 0.27 | 1.10 |
| Run contact velocity impulse | 0.62 | 2.40 |
| Walk / run contact pitch impulse | 0 / 0 | 0.08 / 0.16 |
| Player spring frequency | 3.6 Hz | 3.5 Hz |
| Player damping | 0.48 | 0.36 |
| Player vertical cap before lab multiplier | 0.024 m | 0.075 m |
| Player rotational cap | 0.045 rad | 0.065 rad |
| Chest / head / arm follower frequency | 4.2 / 5.0 / 4.4 Hz | 3.8 / 4.2 / 3.6 Hz |
| Chest vertical following | 0.60 | 0.45 |
| Hand / weapon relative movement cap | 0.010 m / 0.022 rad | 0.014 m / 0.030 rad |
| Production strength | 100% | 100% |

The new player-specific frequency/damping/caps avoid altering values read by zombies.
At production strength the tested walk hip range is -3.40 cm to +1.02 cm; run is
-6.76 cm to +2.03 cm. This gives a visible compression/rebound rhythm through the
normal orthographic gameplay camera rather than relying on close Lab framing.
The comparison GIF is an enlarged crop captured through that unchanged camera.
Run remains noticeably stronger than walk. Aim uses 60% body response and 40% of
LowReady's relative weapon follow. Slower combat cadence further calms Aim movement.
Both arms and the socket still move as one rigid cluster; leg-anchor compensation
preserves sampled foot placement. No mesh scaling or additional joint bending.

`tests/movement_weapon_run_comparison.gif` compares previous and current run tuning.
`tests/movement_weapon_game_{walk,run}_{compress,off}.png` retain full gameplay framing.

## Shot profiles

| Weapon | Damage | Interval | Projectiles / trigger | Target range | Travel range | Speed |
|---|---:|---:|---:|---:|---:|---:|
| Pistol | 20 | 0.50 s | 1 | 8 m | 12.6 m | 14 m/s |
| M4A1 | 12 | 0.12 s | 1 | 10 m | 15 m | 20 m/s |
| Shotgun | 10 per pellet | 1.00 s | 7 | 6 m | 7 m | 18 m/s |

Shotgun uses a centre pellet plus six different directions on a staggered ring.
The cone has a 10-degree half-angle (20-degree full angle), rotated slightly each
trigger. Each thin streak uses the existing swept-ray projectile and may hit its
own target. A close target received 70 damage; a spread fixture hit three separate
targets for 10 damage each. One recoil impulse, flash and shot sound occur per
trigger, rather than seven. M4 preserves the existing authored recoil composition,
queued clip continuation and 1.45 gain bound; no repeated time resets or spring runaway.

Original pistol inspector stats remain the progression contract. Effective shot
values derive from profiles plus the existing damage bonus / speed, interval and
range multipliers. Switching does not reset upgrades. This also keeps the existing
0.18s normalized upgrade floor from slowing the faster rifle. No progression code
or reward tables changed. Debug HUD displays the effective selected-weapon interval.

Muzzle flash is two shared emissive cuboids forming a short angular cross, starting
at the existing `Muzzle_Point`, aligned with the shot. It shrinks and disappears;
there are no new lights or particles. Pistol size multiplier 0.75 / 40ms; M4 0.95 /
35ms; shotgun 1.45 / 55ms. Deterministic small size/twist variations cost no RNG.
Single-projectile weapons avoid allocating a pellet-direction array.

## Movement rule

Actual post-`move_and_slide` horizontal speed must be **<= 3.0 m/s** to fire.
The gun processes after player motion; the combat shot service also guards the rule.
When a target is available, non-sprint movement uses **2.6 m/s** in every direction.
Free walk remains **4.25 m/s**, free run **6.25 m/s**. Holding sprint retains full
run speed when targets enter range. Above the threshold the pose lowers toward
LowReady and shots stop; slowing below it raises Aim and resumes ordinary cooldowns.
Blocked time does not accumulate a burst. Fractional physics-tick timing is retained
only during active eligible firing so 0.12s does not round to 0.133s.

## Test again

Open `scenes/PlayerPoseLab.tscn` and run the current scene (F6):

- `1/2/3`: weapon; `I/W/R`: Idle/Walk/Run; `L/A`: LowReady/Aim.
- `F`: one recoil, muzzle flash and harmless tracer/spread preview.
- `G`: continuous profile-rate preview (especially useful for M4A1).
- `B`: bounce toggle; buttons: 0/50/100/150/200%; `T`: hit impulse.
- Side / 3/4 / Isometric buttons, RMB orbit and wheel zoom.
- Space freezes animation **and** preview effects; period steps a frame.
- `N/H/Q`: 1x / 0.5x / 0.25x. Lab permits firing previews during Run.

Run `scenes/CuboidGameplayTest.tscn`, select a startup weapon, then move with WASD.
With a target nearby, walk/strafe/backpedal fires at 2.6m/s; hold Shift to run and
block fire. Release Shift to return to Aim. Debug HUD shows weapon, locomotion,
effective interval, actual speed, threshold, eligibility and pellet count. `1/2/3`
switch, F2 reopens selector, R resets; L/K/J retain existing debug controls.

Automated focused validation:

```powershell
& '<Godot console executable>' --headless --path game_mobile_3d --fixed-fps 60 --script res://tests/validate_movement_weapons.gd
& '<Godot console executable>' --path game_mobile_3d --rendering-method mobile --rendering-driver d3d12 --fixed-fps 60 --script res://tests/validate_movement_weapons.gd -- --capture
```

## Validation and limits

Focused suite: 798 checks, headless and Forward Mobile rendered. Regression suites:
1,464 Runtime V2, 1,213 bounce, 143 Pose Lab, 124 weapon selector, 77 combat,
85 progression, 65 spawn and 46 headless damage-feedback checks. This covers
hard turns/stops, recoil settling, rigid scales, unchanged foot poses, EXP, death,
pause/resume, selection/reset and damage feedback. Rendered damage feedback is
also exercised separately with the normal audio hooks.

The contact matrices stay below 12.1mm at up to 200% strength. The side/isometric
images show coherent hands and weapon without obvious face/forearm penetration.
A 200% geometry stress check finds no weapon vertices inside the head; the
existing LowReady stock/torso overlap remains (M4 about 14mm, shotgun about 38mm,
including roughly 3mm additional spring overlap). Aim clears the chest. These
checks complement visual inspection; vertex bounds are not exhaustive mesh collision.
200% is an exaggeration control, not the production default. Original locomotion
stride/foot sliding characteristics remain; this layer adds no foot displacement.

Desktop benchmark, RTX 4070 Ti SUPER / Godot 4.7.2 Forward Mobile:

- M4: 83 shots in 10s, peak 2 concurrent bullets with a target 4m away.
- Shotgun: 10 bursts in 10s, peak 7 concurrent pellets.
- Shot construction plus cleanup: roughly 20–25us M4, 66–73us shotgun burst.
- Swept projectile CPU tick: roughly 1.7–1.9us per bullet, 12us for seven pellets.
- Rendered firing and 40 live moving zombies with sustained M4 fire: about 120 FPS
  (display/vsync limited). Headless crowd frame wall time about 2.2ms.
- No phone profiling yet. Empty-air rifle misses may have more concurrent bullets
  than the close-target benchmark. Stress timing suppresses audio only in the test
  harness; the production audio remains unchanged. No pooling framework was added.

## Changed files

Modified runtime / Lab:

- `scenes/PlayerPoseLab.tscn`: updated help.
- `scenes/combat/MuzzleFlash.tscn`: shared emissive cross geometry.
- `scripts/auto_pistol.gd`: effective profiles, actual-speed eligibility, stable cadence.
- `scripts/bounce_tuning.gd`: player-only spring tuning; zombie/common values preserved.
- `scripts/combat_director.gd`: independent pellets, one flash/recoil per trigger, speed guard.
- `scripts/cuboid_player.gd`: combat speed, measured-speed stance eligibility, profile selection.
- `scripts/gameplay_test.gd`: debug interval/speed/eligibility/pellet HUD.
- `scripts/player_animation_v2.gd`: stronger player contacts/follow, Aim stabilization, 200% range.
- `scripts/player_pose_lab.gd`: sustained shot presentation, harmless spread, shared preview clock.

Added runtime:

- `scripts/weapon_fire_profiles.gd` and `.uid`: profile table and deterministic cone.
- `scripts/muzzle_flash.gd` and `.uid`: short per-weapon presentation.

Validation / documentation:

- Modified `tests/validate_bounce_animation.gd`: 200% range / player-specific cap.
- Modified `tests/validate_damage_feedback.gd`: effective per-weapon shot damage.
- Added `tests/validate_movement_weapons.gd` and `.uid`.
- Added this document.
- New evidence only: `tests/movement_weapon_*.json`, `tests/movement_regression_*.json`,
  `tests/movement_weapon_*.png` with generated `.import` metadata, and the comparison GIF.
  Existing reports are retained. Temporary capture/runner files are under ignored `.godot/`.
