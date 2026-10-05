# Animation Runtime V2

## Running

Open the existing `project.godot` and run `CuboidGameplayTest.tscn`. WASD moves,
Shift runs, and R resets. Debug builds: **1 Pistol / 2 M4A1 / 3 Shotgun**.
The small animation HUD below the help panel shows weapon, gait, ready/aim,
target state, firing and measured movement speed. It updates four times/second.
Weapon keys are ignored while paused, leaving upgrade selection's 1/2/3 intact.

Switching changes presentation only. Damage, projectile type, fire interval,
progression, nearest-target selection and audio remain the existing combat
prototype. No shotgun pellets, rifle automatic-fire gameplay, inventory,
reload or pump gameplay were added. Repeated rifle shot events are supported
and tested by the animation controller independently of the default cadence.

## Architecture

`player_animation_v2.gd` is the sole runtime skeleton pose writer. Its imported
AnimationPlayer owns the action library but is stopped after initialization.
`animation_pose_sampler.gd` caches native Animation position/quaternion track
indices per bone. The controller samples these tracks directly rather than
maintaining independent AnimationTree clocks. This Godot 4 equivalent makes
normalized walk/run phase explicit and avoids competing animation writers.

Composition order:

1. Idle / Walk / Run positions and shortest-path quaternion blends.
2. Override Arm.L, Arm.R and WeaponSocket with calibrated weapon Raise pose.
3. Directional hips, target-facing chest compensation, subtle procedural motion.
4. Reference-relative upper-body recoil; no hip or leg recoil tracks.

Only bone translations and normalized rotations are written. Bone scales,
mesh geometry, UVs and skin weights are not changed. Bones and track references
are cached at setup, with no node searches, dynamic arrays, IK or physics in the
player pose loop. There is no per-frame play/restart/seek operation.

The underlying native APIs are documented in Godot's
[Animation reference](https://docs.godotengine.org/en/stable/classes/class_animation.html)
and [Skeleton3D reference](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html).

## Imported actions and reproducible assets

`tools/export_animation_v2.py` opens the two V2 source blends in background
Blender without saving them, selects only the character mesh and rig, exports
named GLB actions, and copies the three unchanged V4 weapon GLBs.

| Layer | Imported actions |
|---|---|
| Player base | Player_Idle, Player_Walk, Player_Run |
| Pistol | Pistol_LowReady, Pistol_Aim, Pistol_Raise, Pistol_Recoil |
| M4A1 | LongGun_LowReady, LongGun_Aim, LongGun_Raise, Rifle_Recoil |
| Shotgun | Shotgun_LowReady, Shotgun_Aim, Shotgun_Raise, Shotgun_Recoil |
| Zombie | Zombie_Idle, Zombie_Walk |

All 15 player and two zombie action names survive import. REVIEW composites are
excluded. Player has the original ten bones plus non-deforming WeaponSocket;
zombie retains ten. Each character remains a 72-triangle mesh with six rigid
cuboids and its existing atlas. Export checks all 144 exported vertices have
exactly one nonzero, unit bone weight. The manifest records source SHA-256,
action names, vertex/joint counts and unchanged weapon hashes.

Blender recoil channels originally contain Euler differences. Export reconstructs
their absolute reference poses before GLB quaternion conversion. Runtime adds
`sample_position - initial_position` and multiplies
`inverse(initial_quaternion) * sample_quaternion`. It never treats raw Euler
differences as absolute bone orientations. These exported recoil actions must
be composed by this controller, not played as full-body absolute actions.

## Locomotion and direction

Real horizontal velocity after `move_and_slide()` drives the controller. Idle
blends toward motion over the first 0.5 m/s. Walk-to-run weight uses smoothstep
between 4.25 and 6.25 m/s. Weights reach their targets over 0.13 seconds.
There is one persistent normalized gait phase, independent of stance and recoil.
Cycle rate is speed divided by blended authored stride distance: **0.94 m walk**
and **1.6 m run**. Both clips sample this same phase at their own durations.
Idle breathing retains its own clock. Stopping does not reset gait phase.

Without a target the visual follows movement; with a target it turns toward
the existing nearest living zombie. Local movement X/Z continuously steer the
hip/leg stride plane, with a closest-plane choice to avoid a discontinuity at
the strafe/backward boundary. Signed travel reverses phase for backpedaling.
Chest rotation cancels the directional hip adjustment, keeping the arms and
weapon oriented toward the target. Forward, backward, both strafes and diagonals
reuse the same three base actions. No eight-direction clip copies are created.

Exposed inputs/state: `has_target`, `is_firing`, `weapon_type`, `movement_speed`,
`local_move_x`, `local_move_z`, `acceleration`, `turn_rate`, `recoil_amount`,
`locomotion_phase`, `aim_weight` and `run_weight`.

## Weapons and contact

`player_weapon_socket.gd` creates one BoneAttachment3D on WeaponSocket and loads
the three existing V4 assets once. Exactly one is visible. The socket adapter
undoes the standalone weapon GLB's Y-up conversion with a 90-degree X rotation;
source models and Grip_Point / Support_Hand_Point / Muzzle_Point are unchanged.
Projectile/muzzle-flash origin now uses the equipped Muzzle_Point. Weapon keys
live in `animation_weapon_debug.gd`, separate from future inventory logic.

Ready/aim traverses the authored Raise curve over 0.13 seconds, forward or
backward. It therefore uses the authored contact-preserving path instead of
naively interpolating unrelated endpoints. Weapon switches crossfade the
previous arm/socket pose over 0.13 seconds without changing the gait phase.

| Weapon | LowReady / Aim behavior | Recoil |
|---|---|---|
| Pistol | Compact two-hand grip at sternum; raised toward face line with face visible | Small arm/socket rise, rearward motion and chest response; 0.233 s |
| M4A1 | Grip/support-marker calibrated long-gun hold, depressed muzzle in ready; raised upper-chest aim | Small controlled rise and shoulder response; 0.167 s |
| Shotgun | Separate calibration puts support hand near pump; shared long-gun controller | Stronger torso/weapon response with 0.433 s recovery |

Walking inherits controlled chest bob from the base. Running inherits the
authored forward lean and adds a small ready-only carry pitch. Acceleration and
braking have bounded chest lean; filtered turn rate adds tiny torso lag. Head
counter-motion reduces the extra rotation. A slower filtered acceleration term
adds carry follow-through. Chest, arms and socket move together to retain both
contacts. No per-frame reach solver or limb scaling is used.

Actual shot events trigger recoil. An active recoil is not restarted by another
shot: its gain is bounded to 1.45 and one subsequent impulse may be queued.
This bounds work and prevents repeated full-body jolts. Weapon switching clears
the pending impulse. `Shotgun_Pump` is reserved for a future weapon-local layer;
the pump mesh remains unchanged and static in this revision.

## Zombies and lifecycle

Zombies use the revised forward-arm Idle/Walk through the shared lightweight
AnimationPlayer helper. Spawn position gives deterministic phase and a 0.95–1.05
cadence multiplier, independent of the existing movement-speed variation.
Idle/walk transitions transfer normalized phase rather than synchronizing every
enemy to frame zero. No added zombie IK or procedural bone loop is used.

SceneTree pause freezes both player and zombie animation. Defeat freezes player
phase and preserves the existing death/lunge lifecycle. Scene reload creates a
fresh controller/socket with Pistol equipped. Target disappearance blends back
to ready rather than snapping. Rapid target changes use interpolated visual yaw.

## Validation and performance

Godot 4.7.2, Windows, D3D12 Mobile renderer. `tests/validate_animation_v2.gd`
covers all three weapons, idle/walk/run, target/no target, forward/back/strafe/
diagonal travel, firing while moving, target loss, rapid stance and weapon
changes, repeated shots, recoil settlement, unchanged leg pose during recoil,
unit bone scales, phase continuity, pause/resume, paused shortcut isolation,
defeat and five zombie phase/rate samples. Assertions and measurements are in
`tests/animation_v2_validation.json`.

Existing regression results: gameplay 370 checks, combat 77, progression 85,
spawn 65, polish 42 headless / 43 rendered. Movement suite assumptions were
updated for the non-deforming socket and isolated character mesh, and polish
assertions now inspect V2 cadence and upper-body recoil rather than obsolete
whole-model recoil. Gameplay combat and progression behavior remain covered.

The V2 matrix has **1,442 passing checks**. Sampled hand-contact error across
ready/aim, motion and recoil is below **12 mm** (15 mm test limit). This is not
a guarantee of exact contact during rapid weapon crossfades. Both three-quarter
and side pose galleries were rendered and inspected; the gameplay debug HUD
was moved out of the EXP bar after rendered review found an overlap.

The 1,000-update player microbenchmark is around **24–25 microseconds/update**
on this desktop, excluding rendering. Character GLBs are approximately 114 KB
and 48 KB. Three weapon instances are allocated once; hidden weapons are not
drawn. Only the player has the extra sampler/procedural work. A small rendered
combat sample was around 120 FPS and 44 draw calls on an RTX 4070 Ti SUPER;
this is desktop evidence, **not a phone budget measurement**.

### Visual limits

- The unchanged 4.25/6.25 m/s gameplay speeds exceed the authored nominal speeds.
  Distance-correct cadence is consequently brisk: about 4.52 walk cycles/s and
  3.91 run cycles/s. Slower cadence would increase sliding without longer clips
  or different gameplay speeds. Neither source clips nor gameplay speeds changed.
- Rigid feet roll between corners; turning, gait blends and uneven terrain can
  still slide. No foot planting/IK is claimed.
- Fixed cuboid hands obscure some receiver detail. Long-gun stock/body proximity
  is inherited from the calibrated authored poses. Sampled gallery poses keep
  the face visible, but do not prove absence of clipping at every instant.
- Crossfading between different weapon calibrations can briefly lose exact hand
  contact. Ready/aim uses the authored Raise path and is more accurate.
- Firing before aim finishes applies the Aim-relative recoil to the transitional
  stance. The measured contact tolerance includes low-ready firing.
- Repeated shots coalesce into a bounded active gain and one queued impulse,
  rather than preserving an unbounded individual visual impulse per projectile.

## Reproduce

From the repository root, using installed Blender/Godot executables:

```text
blender --background --python game_mobile_3d/tools/export_animation_v2.py
godot --headless --path game_mobile_3d --editor --import --quit
godot --headless --path game_mobile_3d --script res://tests/validate_animation_v2.gd
godot --path game_mobile_3d --rendering-method mobile --rendering-driver d3d12 --script res://tests/validate_animation_v2.gd -- --capture
```

Run `validate_gameplay.gd`, `validate_combat.gd`, `validate_progression.gd`,
`validate_spawn.gd` and `validate_polish.gd` the same way. Rendering tests should
run sequentially. In the restricted workspace, APPDATA was redirected to
`.godot/validation_appdata`; editor settings safe-save emitted a sandbox warning,
but assets imported and runtime tests completed without script errors.

## Files changed

- Added `scripts/player_animation_v2.gd`, `animation_pose_sampler.gd`,
  `player_weapon_socket.gd`, `animation_weapon_debug.gd` and generated UIDs.
- Updated `scripts/cuboid_player.gd`, `cuboid_animation.gd`, `cuboid_zombie.gd`,
  `auto_pistol.gd`, `combat_director.gd`, `gameplay_test.gd`.
- Updated `scenes/characters/CuboidPlayer.tscn`, `CuboidZombie.tscn`, and added
  only the animation HUD label in `scenes/CuboidGameplayTest.tscn`.
- Added `tools/export_animation_v2.py`, V2 character GLBs/manifest and copied
  weapon GLBs in `assets/weapons/`, including Godot import/atlas sidecars.
- Added `tests/validate_animation_v2.gd`, JSON results, gallery and side images;
  updated `validate_gameplay.gd`, `validate_polish.gd`, relevant results and
  rendered polish captures.
- Added this document. Existing Blender sources and arena geometry are untouched.
