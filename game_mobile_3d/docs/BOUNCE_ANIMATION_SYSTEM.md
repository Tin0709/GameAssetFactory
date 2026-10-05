# Bounce animation system

Runtime V2 keeps its existing locomotion, stance, procedural movement and recoil layers. A new bounded secondary-motion layer adds elastic compression, delayed follow-through and settling. All parts remain rigid cuboids: geometry, bone counts, scales, weapon hold constants and imported animation libraries are unchanged. Nothing committed or pushed.

## Architecture and spring philosophy

`secondary_spring.gd` stores two Vector3 values per spring: displacement and velocity. Channels represent vertical translation, pitch and yaw. Impulses modify velocity; a closed-form damped response moves the displacement toward its target. Position and impulse limits prevent runaway motion. Quaternions compose the resulting rotations, with normalization at pose writes. Repeated hits/fire never redefine the rest pose.

The player has five states: hips/body, chest, head, arms and weapon. Body reacts first; torso follows; the smaller head response stabilizes later; the arm/weapon cluster follows last. Vertical chest/head offsets provide a small timing difference in translation as well as rotation. Player propagation uses up to eight small integration slices per display frame, targeting 120 Hz. Analytic stepping remains bounded during long frames; the slice cap bounds CPU cost.

The controller remains the only player skeleton writer. Each frame rebuilds the original sampled pose, adds existing movement/recoil, applies secondary offsets, then uses the existing final hand-contact correction and weapon-switch blend. This avoids accumulating offsets on an already corrected pose.

## Foot contacts, idle and movement

Two contact markers are tied to the existing locomotion phase at 0 and 0.5, the alternating stride-reversal/planted portions of the imported gait. Phase-boundary crossings handle wrapping and reverse strides. Contact timing shares Runtime V2's calibrated walk/run cadence; there is no independent locomotion oscillation clock.

- Walk applies a small downward velocity impulse, compression, rebound and settle.
- Run uses a larger impulse for a controlled body thump. The validated maximum added body displacement was approximately 22.5 mm at the lab's 150% strength; normal defaults are smaller.
- Rigid leg anchors counter-translate the added hip translation. Their sampled global foot transforms stay unchanged by the added layer.
- Idle follows the existing authored breathing at very low strength; it does not generate contact impulses.
- Acceleration and stopping feed a bounded pitch target, producing lag and a quick overshoot. Turn rate feeds bounded yaw follow-through. Physics velocity and control responsiveness are unchanged.
- Actual floor contact invokes the exposed landing impulse. No jump mechanic was introduced.

## Weapons, recoil and player hits

Both arms and the socket receive one coherent secondary transform about the chest before final contact correction. The weapon can lag the torso without separating the two-hand grip. Relative socket translation is limited to 10 mm and rotation to 0.022 radians (about 1.26 degrees).

Aim retains 45% of the normal weapon-follow amplitude. Pistol frequency is highest; M4A1 follows later; shotgun has the lowest frequency and greatest mass gain. Original per-weapon placement, scales, grip/support points and shoulder offsets remain untouched.

The existing authored recoil remains primary, including its repeated-shot queue and gain cap. A small velocity kick adds secondary follow-through, with impulse and displacement caps. It cannot permanently move the rest pose. Shotgun has the strongest secondary kick and longest follow-through.

Accepted player damage adds a quick directional body impulse. The melee caller supplies the incoming direction; callers without a direction receive a small fallback response. Hurt grace, red flash, overhead HP, numbers, audio and control all remain in their existing paths. Defeat freezes the visual response; reset creates fresh states.

## Cheaper zombie motion

`zombie_animation_secondary.gd` extends the existing presentation helper. It manually advances the imported AnimationPlayer, captures its unmodified pose and adds three states: body, shoulders and head. The next sample restores that base first, preventing offset accumulation and competing writers. Existing attack/lunge and playback-rate behavior remains.

Walk contacts use the actual imported animation phase. Existing spawn-position phase/rate variation also changes impulse strength and damping slightly, preventing a synchronized crowd. Rigid leg compensation preserves the sampled feet. Shoulders/head lag, and the raised arms receive a small asymmetric follow-through.

Accepted projectile hits kick the body response in local hit direction. Existing HP, knockback, flash and sound still run. The effect settles during continued chase and does not impose a hit-animation lockout.

## Procedural toy-body death

Death stops collision/AI and removes the zombie from the living registry immediately, as before. It then captures the actual visual pose, including the current gait/hit offsets, and interpolates rigid limbs toward loose targets. Arms fling outward from the forward stance; legs separate; the head follows later. The root rotates about the hips and translates along the incoming hit direction.

Six cycling parameter combinations provide directional backward, left/right-biased, side-collapse and stronger-launch variants. Incoming direction rotates that family into the hit's orientation. Variant-specific twist, arm spread, leg angles and existing phase variation keep the poses asymmetric.

Default timing:

| Stage | Approximate time after lethal hit |
|---|---:|
| Throw/fall | 0–0.409 s |
| One ground rebound and settle | 0.409–0.620 s |
| Stable corpse hold | 0.620–1.070 s |
| Existing smoke begins; corpse removed; EXP emitted | 1.070 s |
| Smoke finishes | 1.770 s |

The single ground rebound reaches at most 32 mm. There is no repeating corpse oscillator. Eight corners per rigid part are cached once from the existing skin/bind data. During death those bounds keep every part above the current flat arena floor, with 4 mm clearance. `zombie_rigid_cache.gd` holds only numeric data and the variant counter, independently of actor lifetimes.

Smoke is positioned from the final Chest bone, including the root's throw/fall. EXP remains at the actor's original death position. Its emission is intentionally later by the new 0.45-second corpse hold. Collision, kill registration and target exclusion still happen immediately at death start.

## Central tuning

Edit `materials/BounceTuning.tres` in the Inspector. Default values live in `scripts/bounce_tuning.gd`; both controllers use this same resource. The lab changes only local enable/strength fields, never this resource.

| Parameter | Default | Purpose |
|---|---:|---|
| bounce_strength | 1.0 | Production multiplier |
| bounce_frequency / damping | 3.6 Hz / 0.48 | Body compression/rebound/settle |
| walk / run contact impulse | 0.27 / 0.62 | Downward contact velocity |
| landing_impulse | 0.45 | Floor-contact compression |
| max_body_drop / angle | 0.024 m / 0.045 rad | Body state bounds |
| acceleration / turn strength | 0.0009 / 0.004 | Start/stop and turn lag |
| chest / head / arm frequency | 4.2 / 5.0 / 4.4 Hz | Propagation timing |
| head follow / idle follow | 0.40 / 0.12 | Stabilization and micro-breathing |
| chest / head vertical follow | 0.60 / 0.30 | Delayed vertical response |
| weapon follow / aim stabilization | 0.90 / 0.45 | Hand-cluster amplitude |
| weapon frequencies: pistol/rifle/shotgun | 4.6 / 3.8 / 3.3 Hz | Relative mass/delay |
| weapon mass gains | 1.0 / 1.05 / 1.16 | Heavier follow-through |
| secondary recoil impulses | 0.055 / 0.070 / 0.110 | Small additive firing response |
| player hit impulse | 0.34 | Quick directional response |
| zombie contact / hit impulse | 0.24 / 0.60 | Shamble and shot response |
| zombie frequency / damping | 3.1 Hz / 0.55 | Cheap crowd defaults |
| zombie displacement / angle limit | 0.014 m / 0.075 rad | Crowd bounds |
| death launch / lift | 0.25 m / 0.09 m | Root throw, varied per preset |
| ground rebound / corpse hold | 0.032 m / 0.45 s | One settle and readable final pose |

Reduce strength/contact impulses first if movement feels too lively. Raise damping for quicker settling; lower weapon frequency modestly for more mass. Keep translation/angle limits conservative to preserve the accepted hold. Six pose combinations are defined in the zombie controller near `start_death`, separately from the shared motion tuning.

## Pose Lab controls

Open `scenes/PlayerPoseLab.tscn`, press F6:

- B: Bounce ON/OFF. Strength buttons: 0%, 50%, 100%, 150%.
- N/H/Q: 1x / 0.5x / 0.25x. All spring, gait and recoil clocks use that speed.
- T: preview a player hit impulse, without combat or HP changes.
- I/W/R: Idle/Walk/Run; L/A: LowReady/Aim; F: existing recoil.
- 1/2/3: pistol/M4A1/shotgun.
- Space: freeze; period: single frame. Camera/orbit/zoom remain interactive.
- Camera buttons, RMB orbit, wheel zoom, C reset and V next view remain available.

Compare ON/OFF at the same gait phase with freeze/step. Use 150% as a lab exaggeration, then return to 100%. Lab values do not affect a separately instantiated gameplay player. Panel spacing/help text was tightened so the additional controls fit the 720p window.

## Mobile strategy and validation

Five player states, three zombie states, cached skeleton indices, one numeric geometry cache and bounded math. No rigid-body ragdolls, joints, IK, per-bone physics nodes, asset regeneration or new rendering effects. Death uses ten rigid pose transforms and cached bounds; existing eight-cube smoke remains unchanged. Pause freezes both spring and corpse clocks; scene reset frees actors/effects. Final suites shut down without leaked-object warnings.

Final dedicated results: 997 headless checks and 1,031 rendered checks passed. Existing regression suites passed: animation 1,464, combat 77, progression 85, spawns 65, Pose Lab 143, damage feedback 46 headless and 52 rendered. The rendered feedback suite retained audio-hook checks and shut down cleanly. Death-related waits in four tests were extended for the new corpse hold; HP/stat assertions and mechanics were retained.

The matrix covers all weapons, Idle/Walk/Run, LowReady/Aim, 0/50/100/150% strength, start/stop, hard turns, hits, repeated recoil, frame rates 15–120, hitch stability, foot transforms, six directional deaths, pause/hold/smoke/EXP cleanup and 40 simultaneous deaths. Original model scales/bone counts remain unchanged. Maximum hand-contact mismatch remained about 12.1 mm in the broader animation regression, within the original 15 mm tolerance. All measured rigid death bounds stayed above the floor.

Desktop Mobile/D3D12 sample, RTX 4070 Ti SUPER:

| Workload | Measured cost/result |
|---|---:|
| Player lab update | ~0.046 ms |
| Forty zombie visual updates, springs OFF | ~0.167 ms total |
| Forty zombie visual updates, springs ON | ~0.315 ms total |
| Added spring cost for forty | ~0.148 ms total |
| Forty death-pose updates | ~0.250 ms total |
| Rendered forty-zombie playback OFF / ON | 118.6 / 119.6 FPS |
| Rendered forty-death disappearance sample | ~120.0 FPS |

Samples are desktop observations with frame pacing, not phone-budget guarantees; noise explains the small FPS differences. Audio was excluded from this animation stress benchmark and retained in the separate feedback/combat validation paths. Saved HUD FPS during manual pose stepping is not a performance measurement. No phone was tested.

To rerun from the project directory:

```powershell
godot --headless --path . --fixed-fps 60 --script tests/validate_bounce_animation.gd
godot --path . --rendering-method mobile --rendering-driver d3d12 --fixed-fps 60 --script tests/validate_bounce_animation.gd -- --capture
```

Use the installed Godot executable path if `godot` is not on PATH. For gameplay, run `scenes/CuboidGameplayTest.tscn`; select/switch weapons, accelerate/stop/turn with WASD, use Shift to run, approach melee range for hits, K/J for enemies, L for level-up pause, and R for reset.

## Files and artifacts

Changed:

- `scripts/player_animation_v2.gd`
- `scripts/cuboid_player.gd`
- `scripts/cuboid_zombie.gd`
- `scripts/player_pose_lab.gd`
- `scenes/characters/CuboidZombie.tscn`
- `scenes/PlayerPoseLab.tscn`
- `tests/validate_combat.gd`
- `tests/validate_damage_feedback.gd`
- `tests/validate_progression.gd`
- `tests/validate_spawn.gd`

Created:

- `scripts/secondary_spring.gd`
- `scripts/bounce_tuning.gd`
- `scripts/zombie_animation_secondary.gd`
- `scripts/zombie_rigid_cache.gd`
- `materials/BounceTuning.tres`
- `tests/validate_bounce_animation.gd`
- `docs/BOUNCE_ANIMATION_SYSTEM.md`
- `tests/bounce_headless_validation.json`, `bounce_rendered_validation.json`, `bounce_clearance_validation.json`, and separate `bounce_regression_*validation.json` / baseline diagnostic reports.
- 34 dedicated `tests/bounce_*.png` captures: each weapon in both stances at Idle/Walk/Run/fire, player start/stop/turn/hit, four death stages, corpse smoke and crowd view. Six additional `tests/bounce_regression_damage_feedback_*.png` captures record rendered feedback compatibility.

Godot generated `.uid` companions for the new scripts and `.png.import` companions for captures. Earlier reports/captures are preserved. Temporary diagnostics and regression copies live under ignored `.godot/`.

## Remaining visual limits

The accepted LowReady stock/torso overlap remains. A 150%-strength running/fire/hit vertex check found no head intersection; rifle chest overlap increased by about 2.1 mm and shotgun by less than 0.5 mm compared with bounce OFF. That vertex/bounds check is a useful comparison, not exhaustive triangle collision testing. No new severe clipping was visible in the reviewed views.

The spring layer preserves sampled foot motion; it does not retune the existing stride or cadence. Death grounding assumes the current flat arena floor and does not simulate wall/terrain collisions or limb-to-limb collision. Some intentionally loose final poses leave a foot/arm raised, like a rigid toy landing. The rebound is subtle, especially at isometric gameplay zoom. Actual-device performance remains unverified.
