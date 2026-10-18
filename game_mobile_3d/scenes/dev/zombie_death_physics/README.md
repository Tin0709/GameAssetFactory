# Zombie Death Physics Lab — Phase 1, awaiting visual review

Open `res://scenes/dev/ZombieDeathPhysicsLab.tscn` in the existing Godot project and press **F6** (Run Current Scene). F5 still opens WorldMap. On this Mac:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --path "/Users/tin/Desktop/Game Dev/GameAssetFactory/game_mobile_3d" res://scenes/dev/ZombieDeathPhysicsLab.tscn
```

Select **Idle / Walk / Attack**, select a weapon, then press **Space** or **Trigger Death**. **R** resets; **P** pauses/resumes; **F1/F2/F3** choose front/side/three-quarter. Right-drag orbits; the mouse wheel zooms. Scroll the right panel for slow motion, gravity, physics rate, joint limits/damping, camera buttons, cap and stress test. The camera follows the corpse/group without changing its viewing angle. Reset returns to a single zombie. Walk travels at 0.65 m/s by default; its living lane wraps after 4 m and clears velocity history. Set travel to zero for an in-place trial.

All presets are experimental. Panel edits affect the **next death**, and are temporary. For persistent tuning, edit `presets/pistol.tres`, `rifle.tres` or `shotgun.tres` in the Godot Inspector. Set the scene's exports for default cap, lifetime, gravity, solver iterations and physics rate.

| Preset | Total linear impulse | Extra angular impulse | Upward impulse | Limit multiplier |
|---|---:|---:|---:|---:|
| Pistol: light destabilization | 14 N s | 0.7 N m s | 0 | .85 |
| Rifle: directional collapse | 38 N s | 1.8 N m s | 0 | 1.0 |
| Shotgun: off-center, looser rotation | 86 N s | 5 N m s | 10 N s | 1.4 |

Shotgun strength is full to 1.5 m, falling to 20% at 8 m. Five weighted samples route one total impulse to the nearest current box surfaces; spread can share the impulse between torso, shoulder and head. Their impulses sum to the total once. No pellet bodies are created. These are art-directed presets, not firearm specifications. Direction is world-space, independent of the inspection camera; shoulder location follows the character.

## Implementation and source boundaries

The approved [death-physics research](../../../../docs/animation/research/ENEMY_DEATH_PHYSICS_2026_10_18.md) informed this isolated wrapper. It directly instances our existing `assets/characters/zombie_animation_v2.glb`: its original Zombie_Idle (3 s), Zombie_Walk (1.6 s), mesh and ten-bone rest hierarchy. Attack repeats the existing independently authored Idle + .10/.08/.18 s procedural lunge, with a 1.2 s preview interval. There is **no authored attack arm swing in this GLB**. Newer Blender Original Actions are not exported or changed. No Actions & Stuff clips, pack data, assets or private research rigs are loaded by this lab.

`lab_zombie.gd` owns fixed-step animation sampling while alive. `ragdoll.gd` builds seven native PhysicalBone3D bodies under PhysicalBoneSimulator3D: Hips carrier (8 kg), Chest (22), Head (8), arms (4 each), legs (7 each). Six limited 6DOF joints follow the nearest physical ancestors; Spine/Neck remain utility bones. Arms and legs stay single rigid blocks. The finite-inertia Hips carrier supports the torso without changing the skeleton/weights.

Two world-space body-center samples retain root travel, rotation and Model lunge. Handoff pauses the manual AnimationPlayer, preserves the current pose, starts the native simulator, then builds joint frames from **all current body transforms** before the one-time hit. Angular velocity uses a shortest-arc quaternion logarithm with atan2 for small-angle precision. Physics alone writes the simulated bones afterward. No live AI, character capsule, ground clamp, scripted death fall, smoke or VFX path is instantiated.

Joint translation is locked; angular limits are relative to the captured death pose, capped at 80° to avoid Euler-limit singularities. Native cone joints were unstable in local tests, so this prototype uses passive native 6DOF joints. There is no active stiffness motor; the panel truthfully exposes angular limits and body damping. Shapes collide only with the lab's ground, excluding self/corpse collisions. Sleeping corpses still count against the conservative cap (default 4, hard maximum 8). Reset removes complete body graphs; lifetime/bounds cleanup removes corpses after 35 s or below −15 m, never freezes them in midair.

## Validation and remaining limits

Verified on **Godot 4.7.2.stable.official.ed1daf0bf**, using the project's DEFAULT physics backend and native Mobile renderer. No backend/project setting was changed. Lab-only defaults: 30 display FPS, **120 physics Hz / 16 solver iterations**, gravity **9.8 m/s²**. The original living Zombie controller uses 18; that alternative is exposed for experiments. Engine timing and space solver values are restored on exit. The 60 Hz option remains a contact experiment: some phases produced 10–15 cm transient corner penetration, so it is not the stable review preset.

Automated tests cover nine state/weapon trials, 24 additional stride/lunge-phase trials, translated/rotated roots, zero-impact position/orientation/linear/angular velocity transfer, evaluated skin/physics agreement, rigid block transforms, ground support, joint attachment, repeated reset, pause/reset while paused, slow motion, 4/8 simultaneous deaths, admission and cleanup. Native rendered tests exercise the same selection signals and view keys. Saved scene is reopened in a fresh process in the actual project; evidence is in `validation/`.

The final 33-trial 120 Hz sweep sampled every physics tick from release onward and observed at most **39.1 mm transient box-corner floor penetration** and **28.0 mm joint-anchor error**. Settled guards are 25 mm for floor support and 20–25 mm for anchors; these are prototype tolerances, not a claim of perfect contact. Limb/torso overlap can occur because self-collision is disabled. Joint ranges rebase at death rather than imposing one universal anatomical rest pose. The legacy rigid torso articulates around its existing Chest origin, not a rebuilt anatomical waist. Near-center passive pistol deaths may fall forward with the zombie's pre-existing lean; the force direction is not a scripted fall direction.

Inherited speeds are capped at 3 m/s and 10 rad/s to bound fast lunge sampling. Simulated safety caps are 10 m/s and 12 rad/s, not continuous pose tracking. These can limit extreme user impulses; arbitrary slider extremes, airborne hits, slopes, stairs, body-body collision and production transitions remain future validation. Cleanup is an explicit removal, without a dissolve/fade effect.

Short native desktop observations on Apple M2 Pro, 1440×810 captured viewport, Mobile renderer, 30 FPS display / 120 Hz physics (roughly 72 monitor samples over 2.4 s per case):

| Ragdolls | Physics monitor mean / p95 | Median displayed FPS |
|---:|---:|---:|
| 0 (one animated living zombie) | .183 / .517 ms | 30 |
| 1 | .529 / .684 ms | 30 |
| 4 | .655 / 1.002 ms | 30 |
| 8 | .924 / 1.490 ms | 30 |

These are the final real-project process-monitor observations, covering collapse/settling about 0.4–2.8 s after the simultaneous hit; sleeping retained bodies are included. Monitor values can repeat between refreshes. An earlier staging run was slower (1.86 ms for one, 3.01 ms for eight), showing the variability of these short samples. These are not isolated per-body timings or mobile certification. The 120 Hz contact improvement costs more physics work; real-device CPU, thermal, battery and gameplay load remain untested. Do not promote these defaults to production yet.

## Re-run checks

Use the same Godot executable with `--headless --audio-driver Dummy --path <game_mobile_3d> --fixed-fps 120 --script res://scenes/dev/zombie_death_physics/tests/test_handoff.gd`; substitute `test_states.gd` or `test_transfer.gd`. Tests write only user-data results unless `ZOMBIE_LAB_RESULTS` specifies a path. `tests/native_review.gd` requires a graphics session; `ZOMBIE_LAB_REVIEW_DIR` chooses its local PNG/JSON evidence directory. User playtest launches use normal audio. The lab is waiting for visual review; no gameplay integration, approved Action edits or Blender changes were made.
