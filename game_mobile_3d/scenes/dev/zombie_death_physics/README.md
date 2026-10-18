# Zombie Death Physics Lab — V002, awaiting visual review

Open `res://scenes/dev/ZombieDeathPhysicsLab.tscn` in the existing Godot project and press **F6**. F5 still opens WorldMap. On this Mac:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --path "/Users/tin/Desktop/Game Dev/GameAssetFactory/game_mobile_3d" res://scenes/dev/ZombieDeathPhysicsLab.tscn
```

Choose Idle / Walk / Attack, choose a weapon, then **Space**. **R** respawns, **P** pauses, **F1/F2/F3** select front/side/three-quarter; right-drag orbits, wheel zooms. Scroll the right panel for joint resistance, whole-body force share, **Corpse cleanup**, camera and stress controls. Values affect only this lab. Weapon presets are editable in `presets/*.tres`; lifecycle defaults are scene-root script exports. No production integration or artistic approval is implied.

## Stronger, more connected death motion

The previous light impacts and wide passive joints produced local flailing with little travel. V002 transfers most of one hit impulse across the 60 kg body in proportion to each part's mass, leaving a small regional impulse for off-center rotation. All seven shares sum to one event impulse; no full impulse is duplicated per limb/pellet.

| Preset | Forward / upward impulse (N s) | Extra torque (N m s) | Whole-body share | Initial forward speed, Idle |
|---|---:|---:|---:|---:|
| Pistol | 180 / 108 | 1 | .90 | about 3 m/s |
| Rifle | 360 / 180 | 2.5 | .90 | about 6 m/s |
| Shotgun | 600 / 180 | 5 | .96 | about 10 m/s |

Shotgun uses five weighted sample points, no pellet bodies; full strength through 1.5 m, falling to 20% at 8 m. These are experimental art controls, not firearm specifications or reconstructed Dungeons physics. With cleanup deliberately disabled for a full-landing measurement, the Idle presets traveled approximately 2.64 / 6.18 / 11.19 m. The normal short-lifetime review ends earlier and distances depend on phase, hit location and contacts.

Rigid arms/legs are unchanged. Base bend/twist limits: Chest 6°/4°, Head 16°/10°, arms 40°/14°, legs 25°/10°, multiplied by the weapon's .9/1/1.1 limit scale. Translation stays locked. A brief soft restoring torque and relative angular damping oppose loose limb motion; equal/opposite pair torques preserve whole-body travel. An implicit inertia-aware damping solve remains stable in the tested 60 Hz / 2.5 resistance setting. Resistance fades after 1.2 s and shuts off at 2 s, even in extended review mode. The native GodotPhysics 6DOF spring parameters are unimplemented in this engine, so the panel controls this explicit bounded resistance rather than a nonfunctional native spring.

## Short corpse lifecycle

All durations are **simulation seconds from the lethal handoff**, including slow motion. Pause stops lifecycle time too.

| Control | Default | Meaning |
|---|---:|---|
| Total death lifetime | 1.20 s | Target hit-to-removal duration, including fade |
| Active physics target | 1.20 s | Earliest requested physics release; soft while falling/moving |
| Air / landing extension | .60 s | Maximum extra lifetime to preserve an unfinished fall/landing |
| Landing grace | .12 s | Continuous Hips/Chest/Head ground contact before cleanup can begin |
| Fade within lifetime | .08 s | Brief temporary alpha-hash fade supported by Mobile; 0 removes instantly |
| Pool visual models | On | Reuse hidden model instances; rebuild physics on respawn |
| Maximum active ragdolls | 4, hard cap 8 | Admission/stress limit; does not preempt an airborne body |

Full skeletal physics stays active through impact and flight. A short active budget never freezes a midair corpse. If the budget expires and at least two bodies have remained in ground contact with low linear/angular speeds for .10 s, the lab can retain the final evaluated pose and **free all native bodies/joints** early. This is useful when experimenting with a longer visible lifetime. The final pose is captured from `skeleton_updated`, not the animation pose that modifiers revert to outside evaluation. Physics release does not reset the corpse upright.

At the normal cleanup target, an airborne/uncompleted landing can extend up to the configured cap. A foot touching down alone does not finish the landing: Hips/Chest/Head must make continuous ground contact (or the whole corpse must settle safely); physics continues during the fade if still active. At the hard deadline it disappears while moving, rather than freezing in air. An arbitrarily high launch/long fall can therefore outlive the available landing budget; increase the extension explicitly for such experiments. No unlimited landing wait is allowed. The .08 s fade is included in the target, with normal display/physics quantization. There is no smoke, debris or dissolve system.

Cleanup frees the PhysicalBoneSimulator3D, seven bodies, six joints and their collision RIDs. The bounded pool retains only hidden, disabled visuals. Respawn rebuilds a fresh graph, resets all poses/velocities/history/offsets/death flags/fade materials, rewinds the clip, and warms two pose samples before handoff. Turning pooling off frees retired visuals. Reset also clears active corpses safely; no active physical graph is reused.

## Source boundaries and implementation

This isolated wrapper uses existing original `assets/characters/zombie_animation_v2.glb`: original Zombie_Idle (3 s), Zombie_Walk (1.6 s), model/texture and ten-bone skeleton. Attack is the existing independently authored Idle plus .10/.08/.18 s Model lunge repeating every 1.2 s; the GLB has no authored attack arm swing. No Actions & Stuff pack data, animations, rigs or assets are loaded. Blender files, approval statuses, player and production gameplay remain unchanged.

Seven PhysicalBone3D bodies: Hips carrier 8 kg, Chest 22, Head 8, arms 4 each, legs 7 each. Six limited native 6DOF joints follow physical ancestors, bridging utility Spine/Neck bones. Full world-space transforms and sampled velocities retain root travel and Model offsets. Handoff pauses AnimationPlayer without stopping/RESET, then sets joint frames from the actual current pose. The living controller never writes the dead root or simulated bones. Self/corpse collision is disabled; simple boxes collide with the enlarged 60 m lab floor.

Godot **4.7.2.stable.official.ed1daf0bf**, DEFAULT backend, Mobile renderer. Scene-local 30 FPS display / **120 physics Hz, 32 solver iterations**, 9.8 m/s² gravity; restored on exit. 60 Hz remains an experimental contact option. Inherited speed caps 3 m/s and 10 rad/s; simulation safety caps 24 m/s and 8 rad/s. User slider extremes can hit these caps. The camera tracks the fast-moving corpse while preserving its angle/zoom.

## Validation and practical limits

V002 evidence is under `validation/v002_weighted_launch/`; older root validation files describe V001 and are retained as history. Automated suites cover 9 transformed-root state/weapon trials, 24 extra stride/lunge phases, per-tick world/skin/rigidity/anchor/floor checks, zero-impact velocity transfer and single-event impulse conservation, 60/120 Hz angular resistance, repeated reset, pause/slow motion, 4/8 ragdoll admission and lifecycle/pool teardown.

The default nine-case lifecycle sweep measured removal at about **1.208 s**, with Idle/Shotgun **1.475 s**, Walk/Shotgun **1.433 s**, Attack/Shotgun **1.633 s** and Walk/Pistol **1.283 s** to protect core-body landing. A separate elevated case verifies continuing physics beyond a short active target and removal by the bounded deadline. A longer-visibility case checks the actual fallen world pose before/after physics teardown; twelve reuse cycles check fresh transforms, clip phase and velocity. Stress waves leave zero pooled physics bodies.

Contact remains a prototype limitation. The stronger shotgun exceeded V001's strict 50 mm transient corner-floor guard (59.8 mm in one phase); that failed precheck is retained. V002 explicitly uses **75 mm transient for Shotgun, 50 mm for Pistol/Rifle**, while retaining 25 mm settled support and unchanged joint guards. The full Idle launch measurement observed up to 70.7 mm transient corner penetration and 42.2 mm joint-anchor error. This is not perfect contact, and does not claim the old strict criterion passed. Inset colliders, disabled self-collision and captured-pose-relative joints can also permit adjacent limb overlap. Slopes/stairs, arbitrary airborne extremes, crowded gameplay and phone CPU/thermal/battery remain unvalidated.

Native reopened-scene renders and short desktop process-monitor observations are in the V002 evidence folder, along with a 9.4 s original-speed 30 FPS actual-engine clip. One short active window (.12–.82 s after hit, 21 process-monitor samples) on Apple M2 Pro observed mean/p95: living baseline .546/.669 ms; 1 ragdoll 1.349/1.516 ms; 4 ragdolls 2.213/3.523 ms; 8 ragdolls 1.827/3.968 ms, median display 30 FPS. The nonmonotonic results and repeated/stale monitor values make this a noisy desktop observation, not per-body scaling or a mobile benchmark. Every stress wave also verified zero physics bodies in pooled visuals after cleanup. These observations do not establish mobile performance. Cleanup removes the ongoing physics workload after the short burst, but creation/handoff/solver spikes still need real-device profiling. Do not promote this lab to production before visual and device review.

## Re-run

Run the Godot command above with `--headless --audio-driver Dummy --fixed-fps 120 --script res://scenes/dev/zombie_death_physics/tests/test_lifecycle.gd`; substitute `test_handoff.gd`, `test_states.gd`, `test_transfer.gd`, `test_weighted_launch.gd`, `test_joint_resistance.gd` or `test_lab.gd`. `ZOMBIE_LAB_RESULTS` chooses the JSON destination. Long landing tests deliberately override lifetime/active duration to 35 s; lifecycle tests exercise real defaults. `tests/native_review.gd` requires a graphics session; `ZOMBIE_LAB_REVIEW_DIR` chooses local PNG/JSON output. `tests/review_motion.gd` is an original-speed actual-engine movie capture helper, not a benchmark. Automated tests use process-local Dummy audio; user playtests use normal audio.
