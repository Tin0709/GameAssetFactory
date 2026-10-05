# Continuous enemy spawning and difficulty

Run the existing CuboidGameplayTest with F5. It now starts with five zombies and continuously creates new enemies around the perimeter, with a hard cap of 40 living zombies. WASD/Shift, auto pistol, EXP/upgrades and R reset retain their existing behavior. Debug builds: K adds one, J requests ten, L grants the next level. Debug commands obey pause, defeat and the cap. Disable `SpawnDirector.debug_spawn_shortcuts` to turn off K/J.

## Architecture and tuning

One scene-local `SpawnDirector` Node owns the survival clock, schedule, RNG, safety regions and new-enemy difficulty. All important tuning is exported on this node. It preloads the existing zombie scene and reuses `Combat.living_zombies` instead of maintaining a second list or searching the scene tree each frame. Character model/texture/animation resources are shared as before. Its single `spawn_one` acquisition path can later replace instantiate with pooling without changing the schedule or placement API; no pool framework is built yet.

The director seeds `initial_active_target=5` enemies on scene readiness. After that it adds one or sometimes two on each scheduled event whenever there is room below `max_active_zombies=40`. Five is the starting count, not a persistent soft cap. Pressure builds through continuing arrivals, a shorter interval and modest new-enemy stats. At 40 the director skips events without accumulating debt. When a kill frees a slot, the next scheduled event can fill it; debug spawning also respects the same hard cap.

Let `p=clamp(elapsed_survival / ramp_seconds, 0, 1)`, with `ramp_seconds=300`:

| Active survival time | Base spawn interval | New HP | New damage | Nominal speed |
|---|---:|---:|---:|---:|
| Start | 1.60s | 60 | 10 | 2.05m/s |
| 2:30 | 1.05s | 72 | 11 | 2.204m/s |
| 5:00 | 0.50s | 84 | 13 | 2.358m/s |

Base interval is `lerp(initial_interval, final_interval, p)`. Each event has ±14% timing variance; 10% of intervals receive a 1.7× calmer-gap multiplier. There is an 18% chance of a two-enemy event. The second samples a nearby position along the same edge, about 0.95–1.8m away; blocked pairs fall back to other safe candidates. This is continuous pressure, with no waves or phase-transition framework.

New-enemy HP is `round(60 × (1 + 0.08 × minutes))`; damage is `round(10 × (1 + 0.05 × minutes))`; nominal speed is `min(2.75, 2.05 × (1 + 0.03 × minutes))`. HP/damage grow linearly after five minutes too; the interval stops shrinking at 0.5s. The existing ±8% spawn-position speed variation is retained, but actual movement is clamped to 2.75m/s even after variation. Normal zombies remain substantially slower than the player's current walk/run defaults.

Stats, target and initial pursuit flags are assigned before adding the actor to the scene tree, so ready initializes full scaled HP. Existing enemies keep their spawn-time stats: changing survival time does not suddenly heal or strengthen an enemy mid-fight. Standalone zombie defaults remain available for reusable scenes and isolated tests.

`random_seed=1337` gives reproducible sampling for the same inputs; zero randomizes a run. Placement rejection and player movement affect the sequence, so this is a debugging aid, not deterministic network replay.

## Placement and pursuit

Spawns use the inset rectangle x=±7.15 or z=±5.35, feet y=0.02. These coordinates stay inside the current wall inner faces x=±8.0/z=±6.2, leaving clearance for cuboid visuals and capsule collision. Floor/corner pillars remain unchanged. Candidate selection rejects horizontal player distances below 3.25m and existing-living-enemy distances below 0.85m. At most 32 candidates are tried; failure skips safely and increments a debug counter rather than spawning at the origin. No navigation/physics query runs in the director. Validation uses collision queries to verify these predefined areas.

Spawned zombies use `persistent_chase`, a light flag that bypasses the old detection/loss cutoff for these actors. This makes perimeter enemies approach the player even across the whole arena. Other reusable zombie instances retain the original range behavior by default. Target is injected before readiness, avoiding an extra per-spawn player group scan. Existing animation phase/speed variation, rigid limbs, lunge, hit flash and death remain in use.

## Pause, death, cleanup and reset

The director is normally pausable, like gameplay. SceneTree pause therefore freezes elapsed survival time, the current spawn countdown and all enemy/combat simulation during upgrade selection or external pause. A combat/player-state guard also prevents scheduled/direct/debug spawn calls after defeat or during selection. Defeat leaves the clock stopped even though the UI still runs. Resuming preserves the countdown; there is no catch-up burst.

Combat increments `kill_count` once when a registered living enemy begins death, releases the active slot immediately and rejects duplicate death notifications. The existing rigid collapse still lasts 0.62s and produces exactly one EXP. A one-shot `tree_exiting` connection removes registry entries if an actor disappears without dying, without counting a kill. No second active list, per-frame cleanup scan or retained dead reference is added. Temporary dying bodies are excluded from the living cap and can briefly add render cost above 40 bodies.

R reloads a new run: time 0, five newly seeded enemies, kills 0, baseline spawn difficulty/schedule, full player HP, Level 1/EXP 0/default upgrades and fresh transient containers. This also works through the existing paused upgrade overlay reset handler.

## HUD and files

HUD adds MM:SS survival time, alive/cap and kills. HP, Level, speed, FPS and EXP bar/progress remain. Status refresh stays at four updates per second; the underlying HUD freezes during upgrade selection as before.

Created: `scripts/spawn_director.gd`, `tests/validate_spawn.gd`, `tests/legacy_fixture.gd`, spawn validation JSON, gameplay/stress previews, this guide and generated Godot UID/import sidecars.

Updated: `scripts/combat_director.gd` (kill count/tree-exit registry cleanup), `scripts/cuboid_zombie.gd` (injected target, persistent pursuit, actual speed cap), `scripts/gameplay_test.gd` (HUD/debug keys), `scenes/CuboidGameplayTest.tscn` (remove placed zombies, add director). Combat, progression, movement and polish tests use the isolated three-zombie fixture to preserve their earlier assertions; only tests use this fixture. Their reset checks restore that fixture after a real R reload. Existing combat/progression/gameplay/mobile guides describe continuous spawning.

No player movement or weapon defaults, upgrade logic, arena geometry, camera, light configuration, renderer, Blender source or imported character asset was changed for this pass.

## Validation and stress

Run from the project folder (replace godot with the executable):

```text
godot --headless --path . --script res://tests/validate_spawn.gd
godot --path . --rendering-method mobile --rendering-driver d3d12 --resolution 1280x720 --script res://tests/validate_spawn.gd -- --capture
```

The Windows override selects the tested Mobile renderer. JSON is written to `tests/spawn_headless_validation.json` and `spawn_rendered_validation.json`. Preview outputs are `spawn_gameplay.png` and `spawn_stress_40.png`.

Checks cover seeding/continuous arrivals, safe wall/player/corner placement, bounded failure, seeded timing, nearby pairs and calm gaps, curve/stat math, persistent pursuit, cap rejection and scheduled refill, external removal, actual kills/EXP/upgrades, paused survival/countdown, resume, defeat, K/J, reset and 36 repeated deaths with exact drops and no stale references. Five-minute scaling is verified by advancing the director clock in the fixture rather than waiting five real minutes. Earlier combat/progression/movement/polish checks remain available as regressions.

Rendered stress starts with five active zombies and a high-HP test-only player, disables only the pistol, then adds 35. All 40 keep their normal pursuit, collisions, animations, attacks, feedback and audio. It waits two seconds to settle and records six one-second FPS/physics samples, then captures the crowd. The same suite also captures normal movement/autofire gameplay with default HP. High HP and manual clock manipulation exist only in tests.

Passed on Godot 4.7.2: 65 headless spawn checks and 69 rendered spawn checks. Forty-enemy FPS samples were 118–120, compared with 120 at five; draw calls rose from 43 to 113. Reported physics samples were 1.57–2.00ms; process-monitor samples were 9.86–23.50ms, including one higher sample. The movement (354), combat (77), progression (85 headless / 95 rendered) and polish (42) regressions passed. Full desktop results are recorded in the JSON; the FPS comparison checks the 40-enemy minimum against 80% of the five-enemy baseline. This capped desktop result does not establish phone performance or GPU headroom. Shadows and collision crowding grow with count; the active cap controls living enemies, not accumulated EXP drops or brief corpses. Direct steering can crowd tightly around a stationary player, as the stress image shows. Longer phone sessions should profile shadows, draw calls, physics contacts, MP3 decoding, effect allocation at upgraded fire rates and accumulated drops. This pass adds no expensive pathfinding, dynamic lights, simulation or pooling framework. Physical phone/thermal/export tests remain outstanding.
