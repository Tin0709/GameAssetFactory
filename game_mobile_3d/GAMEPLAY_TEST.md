# Cuboid gameplay test

Continuous perimeter enemies and the active cap are documented in [SPAWN_DIRECTOR.md](SPAWN_DIRECTOR.md).

The scene includes auto-fire combat and [level-up upgrade selection](LEVEL_UP_SYSTEM.md). See [COMBAT_PROTOTYPE.md](COMBAT_PROTOTYPE.md) for health, attacks, death/EXP/audio, tuning and combat validation. The movement/import details below still apply.

Open `project.godot` in Godot 4.7.2 and press **F5**. The project now starts `scenes/CuboidGameplayTest.tscn`. Open that scene and press **F6** to run it directly. The previous visual foundation remains available as `scenes/Main.tscn`.

**WASD** moves along world X/Z, **Shift** runs, and **R** resets the arena. Two nearby zombies chase immediately; approach the third to bring it into range. Cyan corner markers and a muted tiled center keep the open arena easy to read. The orthographic camera is static; its size is editable on `Camera3D`.

## Reusable scenes and scripts

| File | Purpose |
| --- | --- |
| `scenes/characters/CuboidPlayer.tscn` | CharacterBody3D, capsule collision, visual wrapper and imported V6 model |
| `scenes/characters/CuboidZombie.tscn` | CharacterBody3D, capsule collision, visual wrapper and imported V2 model |
| `scenes/CuboidGameplayTest.tscn` | Floor, physical boundaries, one player, continuous SpawnDirector enemies, camera, one sun and HUD |
| `scripts/cuboid_player.gd` | Responsive WASD/Shift movement, normalized diagonals, gravity, facing and animation selection |
| `scripts/cuboid_zombie.gd` | Cached player target, range checks, direct pursuit, stop distance and animation selection |
| `scripts/cuboid_animation.gd` | Shared named-loop playback, 0.10-second transitions, nearest sampling and visual turning |
| `scripts/gameplay_test.gd` | Reset input and status display refreshed at 4 Hz |
| `environment/Gameplay.tres` | Existing atmosphere with color-based ambient fill for readable characters |

The collider is an invisible capsule; rendered arms and legs remain single rigid rectangular blocks. Each model has 72 triangles, ten bones, one opaque material and a 64x64 atlas. There is no IK, cloth or pathfinding. Combat uses a lightweight attack lunge and rigid death collapse. Direct chase is appropriate for this open arena; adding interior obstacles would require navigation later.

## Animation behavior

Player movement changes immediately with input. Visual yaw eases toward movement direction, independently of the collider. `Player_Idle` plays below 0.04 m/s actual movement; otherwise walking uses `Player_Walk`, and Shift uses `Player_Run`. Walk speed is 1.3 m/s; run speed is 2.8 m/s. Playback rate follows actual horizontal velocity, with limits to keep poses readable. This is an initial stride calibration rather than a foot-lock system.

Zombies detect the player within 6.5 m, lose the target beyond 8 m, move at 0.6 m/s, and stop within 1.05 m. A 0.20 m restart margin prevents twitching at the stop boundary. `Zombie_Walk` plays while advancing, and `Zombie_Idle` plays when idle, close enough, outside range or blocked. The arms remain raised, with whole-leg shambling and torso sway inherited from V2.

All five named actions are preserved: player idle 2.0 seconds, walk 1.333 seconds and run 1.0 second; zombie idle 2.0 seconds and walk 1.333 seconds. The duplicate closing keys define the export endpoints. Loops are explicitly enabled by the shared visual helper. Root motion is not applied: CharacterBody3D handles all world movement.

## Asset pipeline

`assets/characters/player_cuboid_v6.glb` and `zombie_cuboid_v2.glb` are selected-character-only exports, including skins, all ten bones, named sampled actions and embedded PNG atlases. Blender studio lights/cameras are excluded. Godot extracts the embedded atlases into the same directory during import; these are small, lossless 64x64 PNG files. Import settings use 24 FPS, retain constant animation channels for reliable switching, and disable unnecessary LOD generation/light baking on these tiny dynamic meshes.

The runtime project needs no Blender installation. GLB is a supported Godot scene format: [Godot's format documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html). `tools/export_cuboid_assets.py` is the repeatable Blender/MCP export recipe, and `assets/characters/export_manifest.json` records the source hashes, action names, durations and export sizes. The source blends were not modified.

The original shared materials and `Courtyard.tres` remain unchanged. The new gameplay environment selects ambient color rather than an absent sky: [Godot Environment documentation](https://docs.godotengine.org/en/4.6/classes/class_environment.html#enum-environment-ambientsource).

## Validation

From this project directory, replace `godot` with the installed executable:

```text
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/validate_gameplay.gd
godot --path . --rendering-method mobile --rendering-driver d3d12 --script res://tests/validate_gameplay.gd -- --capture
```

The last command is the Windows rendered validation path used here. Other platforms can omit the driver override. It writes `tests/gameplay_preview.png` and `tests/gameplay_validation.json`.

Validation covers actual keyboard bindings, movement/run/idle switching, normalized diagonals, facing, floor/boundary collisions, chase/range/stop behavior, scene reset, imported clip names/loop endpoints, unit bone scales, nearest sampling and atlas sizes. Both headless and rendered Mobile checks passed on Godot 4.7.2. The original visual scene validation also remains available.

The test contains 27 mesh instances, 564 triangles and eight shadow casters, with one directional light and the existing 1024 shadow budget. Desktop validation does not establish phone performance. This first gameplay pass uses keyboard controls; touch controls, device profiling and Android/iOS export setup remain future work.
