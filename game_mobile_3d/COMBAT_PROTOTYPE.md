# Cuboid combat prototype

Open `project.godot` in Godot 4.7.2 and press **F5**, or run `scenes/CuboidGameplayTest.tscn` with **F6**. **WASD** moves, **Shift** runs, **R** resets. The pistol fires automatically at the nearest living zombie. Move toward cyan drops to collect EXP. The existing arena, camera, Mobile renderer, imported character models and locomotion clips remain in use.

This arena starts with exactly three zombies. After clearing it, collect the drops and press R for another pass; waves and level-ups are not implemented. To inspect melee/defeat without the pistol killing everything first, turn off `enabled` on `Actors/Player/Pistol` in the inspector. Toggle `Combat.combat_enabled` off to inspect movement without damage.

## Tuning

All values are exported inspector properties on their corresponding scripts.

| System | Initial values |
| --- | --- |
| Player (`cuboid_player.gd`) | 100 max/start HP; 0.35 s hurt grace; existing walk/run speeds 1.3/2.8 m/s |
| Pistol (`auto_pistol.gd`) | 20 damage; 8 m target range; 0.5 s interval (about 2 shots/s); 0.15 s initial delay |
| Projectile (`pistol_projectile.gd`) | 14 m/s speed; 0.9 s lifetime; inherited shot damage |
| Zombie (`cuboid_zombie.gd`) | 60 HP; 0.6 m/s chase; existing 6.5 m detection/8 m loss range |
| Zombie attack | 10 damage; 1.15 m reach; 1.10 s interval; 0.12 s windup; 0.28 s visual lunge |
| Hit reaction | 0.09 s instance flash; 1.1 m/s initial knockback, exponential decay at 13/s; 0.14 s single-box impact |
| Zombie death | 0.55 s rigid whole-body collapse, then one drop and removal |
| EXP (`exp_pickup.gd`) | One EXP per drop; 0.70 m horizontal collection radius |

## Health and combat flow

Player HP clamps to zero. Invalid damage, damage during the short grace period, and damage after defeat are ignored. Health/EXP signals update the HUD immediately; living count and FPS refresh four times per second. Defeat freezes movement and zombie simulation, disables the gun, removes active projectiles and blocks EXP collection. The UI continues to process R. Reset reloads the scene, restoring HP 100, EXP 0, three living zombies and fresh cooldowns.

The gun checks a scene-local cached living-enemy registry rather than searching the scene tree every frame. It selects by squared horizontal distance and fires a straight, non-homing projectile toward the target's torso position at shot time. Existing movement/facing stays independent from automatic targeting; there is no held-weapon model or Blender asset change.

Projectiles are small unlit box meshes with one swept physics ray each tick. The ray checks world layer 1 and zombie layer 4, excludes the player, and sweeps the complete traveled segment to avoid tunneling. A hit applies damage once, plays the short impact sound, spawns a tiny burst and frees the bullet. A miss expires after 0.9 seconds, and world collisions also remove it. No projectile RigidBody3D or extra dynamic light is used.

Zombies stop near the player, begin a windup and apply melee damage only if the player is still alive and in range at the strike time. The cooldown prevents per-frame contact damage; moving away resumes chase. Without a `Zombie_Attack` clip, the existing idle pose and a 0.13 m whole-model lunge supply feedback. `cuboid_animation.gd` will prefer an imported attack clip with that name if one is added later; adjust the exported windup to match its strike timing.

Damage uses a per-instance temporary material overlay, so shared atlas resources do not flash other actors. Knockback translates the CharacterBody3D, and death rotates/translates the entire visual while freezing skeletal playback. Character scale remains one: the cuboid parts never bend or squash. At death start, the enemy immediately leaves targeting and living-count registration and its collision is disabled. Further damage is ignored. The corpse drops exactly one EXP object and frees itself after the collapse. `_begin_death`/`_finish_death` are the isolated replacement points for a future authored death animation.

EXP is one shared cyan emissive box mesh with gentle rotation/bob. It has no dynamic light or physics body: collection uses a cached player reference and squared-distance check. A collected flag prevents duplicate awards before deferred removal. There is no level-up system.

## Files created/changed

Created scripts: `combat_director.gd`, `auto_pistol.gd`, `pistol_projectile.gd`, `exp_pickup.gd`, `impact_burst.gd`, `combat_audio.gd`.

Created scenes: `scenes/combat/PistolProjectile.tscn`, `ExpPickup.tscn`, `ImpactBurst.tscn`. Added `materials/HitFlash.tres`, normalized audio names in `assets/audio/`, `assets/audio/audio_manifest.json`, `tests/validate_combat.gd`, rendered combat/defeat previews and validation JSON, and repeatable impact extraction/trimming tools.

Changed: `cuboid_player.gd` (health/EXP), `cuboid_zombie.gd` (health/attacks/death), `cuboid_animation.gd` (instance flash and rigid lunge), `gameplay_test.gd` (HP/EXP/living/FPS and defeat HUD), `scenes/characters/CuboidPlayer.tscn` (gun node), and `scenes/CuboidGameplayTest.tscn` (combat services and HUD). The existing movement regression test disables combat to keep its checks isolated. Guides were updated to reflect combat. No environment geometry, camera, renderer settings or character source/import files were redesigned.

`Combat` owns `Projectiles`, `Pickups`, `Effects` and `Audio`. Actors reference this scene-local service; no singleton or heavy game framework was added. `register_zombie` is also reusable for future spawns: set the spawn position before adding the actor to the tree, then register it.

## Audio

The originals under `audio/game/` are preserved. Copied and integrated: pistol shot, zombie hit/death/attack, player hurt/death, and EXP pickup MP3s. The 14-second bullet-impact recording was decoded with Godot, reduced to a single 0.26-second transient and given 12 ms edge fades; only that short WAV plays per impact. Its extraction position and processing are in `audio_manifest.json`.

Eight scene-owned AudioStreamPlayers each have a three-voice polyphony cap and conservative event volumes. Enemy death tails can finish after the enemy node disappears. Reset stops/reclaims all voices. Sound playback is skipped under the headless dummy driver, while automated checks still verify the streams and short impact duration. Rendered validation exercises the actual audio playback path.

## Validation and performance

Run from this project folder (replace `godot` with your executable):

```text
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/validate_combat.gd
godot --headless --path . --script res://tests/validate_gameplay.gd
godot --path . --rendering-method mobile --rendering-driver d3d12 --script res://tests/validate_combat.gd -- --capture
```

The Windows driver override is the Mobile-rendered path tested here; omit it on other platforms if unnecessary. Rendered results are written to `tests/combat_validation.json`, `combat_preview.png`, and `defeated_preview.png`. Headless results are recorded separately in `combat_headless_validation.json`.

Checks cover nearest/dead/out-of-range targeting, fast swept hits, miss expiry/wall cleanup, auto-fire cadence, three-hit deaths, repeat-damage rejection, flash isolation/cleanup, one-drop accounting, melee cooldown and escaping windup, player HP/grace/defeat, disabled movement, reset, audio resources, and 15 repeated kills/collections. The movement/import suite separately verifies all five locomotion clips, rigid bone scales, loop closure, collisions and controls. Both headless and rendered Mobile runs passed on Godot 4.7.2.

Base arena remains 564 triangles, 27 mesh instances and eight shadow casters. Each active bullet, drop or burst adds one 12-triangle box and no shadows. At the default two shots/s and 0.9 s lifetime, normally at most two bullets are alive; only three enemies/drops exist in the normal test. Flash adds a short extra draw pass on the struck actor. No ragdolls, particle systems, dynamic projectile/EXP lights, or recurring scene-tree scans are used.

Current concerns: desktop validation does not prove phone frame time, battery/thermals or audio cost. The inherited sun/shadows remain the main GPU budget item; MP3 decoding and transient allocations should be profiled before increasing enemy/shot counts. Pooling is unnecessary at this test scale but can be introduced when measured traffic warrants it. Chase is direct, and shots aim at current target position, so obstacles or faster enemies would need navigation/aiming iteration. Touch input and phone exports remain future work.
