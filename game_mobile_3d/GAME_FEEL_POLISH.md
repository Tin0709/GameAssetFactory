# Movement and combat feel pass

Run the existing CuboidGameplayTest with F5. WASD moves, Shift sprints, R resets. Geometry, atlas materials, rig, imported animation data, arena, camera and Mobile renderer are preserved.

## Inspector tuning

| Setting | Default |
|---|---:|
| Player walk / sprint | 4.25 / 6.25 m/s |
| Player acceleration / braking | 42 / 60 m/s² |
| Visual turn response | 16/s exponential |
| Animation transition / rate response | 0.12s / 18/s |
| Walk / run cadence reference speed | 1.55 / 2.8 m/s |
| Walk / run rate bounds | 0.5–2.8 / 0.5–2.5 |
| Zombie chase | 2.05 m/s, stable spawn variation ±8% |
| Zombie turn / cadence reference | 10/s / 1.0 m/s, rate capped 2.2 |
| Melee anticipation / strike / recovery | 0.10 / 0.08 / 0.18s |
| Melee cooldown / reach / damage | 1.10s / 1.15m / 10 |
| Hit flash / knockback decay | 0.09s / 16/s |
| Hit knockback speed | 2.4 m/s |
| Death duration | 0.62s |
| Pickup reach / travel | 0.70m / 0.12s |
| Audio same-event minimum spacing | 0.045s |

Movement uses vector acceleration toward normalized input, separate fast braking and measured horizontal velocity after collision. Idle triggers below 0.12m/s, sprint input selects Run while moving, otherwise Walk. Rate follows actual speed/reference with clamping and exponential smoothing. State changes crossfade, and sustained movement never restarts a clip. Block geometry is never scaled or deformed. Turning follows input with an exponential response and retains facing when input is zero.

The inherited clips have fixed stride lengths. Cadence scaling reduces mismatch, but it does not provide foot locking, and some sliding remains at these substantially higher movement speeds or against obstacles. The rate caps keep the gait readable instead of accelerating it without bounds. A future authored longer stride can improve this further while retaining whole-limb rigidity. This pass does not claim eliminated foot sliding.

## Feedback

Pistol targeting, damage, range, cadence and projectile speed are unchanged. A 45ms opaque, unlit muzzle box appears along shot direction. The whole model recoils 22mm over 35ms and returns over 90ms, leaving movement/collision unaffected. The projectile is a longer 0.38m yellow streak mesh, with swept hits and normal expiry. Existing pistol/impact/hit audio remains connected; simultaneous copies of each sound within 45ms are coalesced, with the existing three-voice per-event cap. No camera shake or global hit stop was added.

Zombie spawn positions choose a stable speed multiplier and idle phase once. Facing and cadence track chase movement; no per-frame random work or tree scans. Attacks hold locomotion for 0.36s, retract the model 45mm during anticipation, advance 190mm during the strike, apply damage at 0.18s if still in range, then recover. Both arms retain the existing forward pose. Killing the zombie cancels the lunge immediately.

Death starts with a 55ms hit recoil, 100ms loss of balance, 335ms sideways/backward fall and 130ms hold. Cheap direction variation uses incoming hit direction or the stored spawn sign. Collision and targeting stop immediately; scale stays one; one EXP drops at the body origin after collapse, then the corpse frees. No ragdoll.

EXP keeps its cyan emissive opaque box, 35mm bob and slow rotation without a light. Once within reach, it travels toward the player's lower torso and shrinks over 120ms, awards once, plays sound and frees. Defeat blocks collection and reset clears all nodes.

## Files

Changed scripts: `cuboid_player.gd`, `cuboid_animation.gd`, `cuboid_zombie.gd`, `combat_director.gd`, `combat_audio.gd`, `exp_pickup.gd`, `gameplay_test.gd`, `impact_burst.gd`.
Changed scene: `scenes/combat/PistolProjectile.tscn`.
Added scene: `scenes/combat/MuzzleFlash.tscn`.
Added tests/report/previews: `tests/validate_polish.gd`, `polish_headless_validation.json`, `polish_rendered_validation.json`, `polish_walk.png`, `polish_combat.png`.
Updated existing combat test waits for the deliberate attack/pickup timings, combat guide and validation results. Generated Godot UID/import sidecars accompany new assets.

## Validation

Run `godot --headless --path . --script res://tests/validate_polish.gd` plus the existing `validate_gameplay.gd` and `validate_combat.gd` suites. Add `-- --capture` to a rendered Mobile polish run for previews. Windows validation uses `--rendering-method mobile --rendering-driver d3d12 --resolution 1280x720`.

The focused suite exercises gradual start, final speed, diagonal normalization, responsive stop, facing, Idle/Walk/Run selection, cadence, no repeated restarts, eight successive shots/recoils and effect expiry, variation, anticipation/impact/recovery, death interruption, corpse/drop cleanup and pickup travel. The combat suite verifies simultaneous enemies, attack cooldowns, reset, 15 repeated kills and exact EXP accounting. The import/movement suite verifies all five rigid loops and collision behavior.

Rendered desktop Mobile validation measured 120 FPS (display cap) and 38 draw calls in the combat capture on RTX 4070 Ti SUPER. This is not a phone benchmark or proof of baseline-equivalent frame times. No new lights, particle systems, constraints, simulations, camera effects or global time scaling. Each flash/streak/burst/drop is one small opaque unshadowed mesh with reusable resources. Short tweens and effects are allocated per event; at two shots/sec and three zombies this is small, but profile allocations, MP3 decoding and inherited shadows before scaling enemy counts. Physical phone performance remains untested.
