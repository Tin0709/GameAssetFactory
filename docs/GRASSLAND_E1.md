# E1 — Grassland integration

Delivered October 8, 2026. **ARTISTIC STATUS: AWAITING HUMAN REVIEW.**

## Assets used

Source: `blender/environment/studies/grass_block_wind_v3/grass_block_wind_v3.blend`.

- `ENV_GrassDirt_Block_1m`: the actual 1 × 1 × 1 m block, pixel grass top, inset dirt body and geometric stepped grass rim.
- `ENV_Grass_Full_Surface_2D`: the actual 49 flat blades, 392 source vertices / 294 triangles, four rings at normalized heights 0, 0.22, 0.65 and 1. Blade heights 0.4807–0.6984 m.
- `ENV_Pixel_Atlas_Opaque` and packed `ENV_Atlas_64_Nearest`, exported as the same 64 × 64 atlas with nearest sampling.
- `ENV_Wind_Global` and the v3 wind study supply the four-second loop, 1.8 cm along-wind / 0.7 cm crosswind tip amplitudes, and height delay. The optional Blender player demo supplies the gentle walking / stronger sprint visual reference.

Source SHA-256: `f1243780e7197d6b3495a43e9e19a145f5e4693bec08c8c502611ba1a2cc20be`. It is unchanged after export. No approved source file was saved or edited.

Export-only changes: copies are made in an isolated in-memory scene, grass is exported in its authored Basis with shape keys/animation omitted, and redundant collinear points on the block's planar top/bottom polygons are removed. The exported block retains its corners, dimensions, UVs and all stepped sides, with 288 triangles. The grass geometry is unchanged. Bend color data and blade root UV2 are exported explicitly; the shader ignores vertex color for albedo. Automatic grass LOD generation is disabled because simplification can remove deformation rings.

Exporter: `blender/environment/export_grassland_e1.py`. Assets and source/export manifest: `game_mobile_3d/assets/environment/grassland/`.

## Scene, terrain and player

Playable scene: **`res://scenes/Grassland.tscn`**, in `game_mobile_3d`.

The map has exactly **40 × 40 = 1,600 cells**, spanning X/Z −20 to +20. Every block is one metre per axis, from Y=0 to Y=1. Source top UVs repeat once per cell. The top is continuous and flat; original geometric rim/dirt surfaces appear at the outer boundary.

Sixteen 10 × 10 chunks combine the actual imported block triangles. Internal sides and underside faces are omitted. Total terrain geometry is **14,560 triangles**, including **3,200 top triangles**. One `StaticBody3D` with one `BoxShape3D(40,1,40)` gives continuous collision, with no per-cell physics.

The scene instances unchanged `scenes/characters/CuboidPlayer.tscn`, currently the R15 production player. Controller, Capsule collision, animation/weapon systems, Walk/Sprint states and input mappings are reused. Spawn is `(0,1.02,0)`, settling at Y=1. The existing camera projection, orientation, size and clipping values are preserved; its position follows the player across the larger map. Existing ambient environment and single sun are reused.

There is no spawn director, enemy actor, combat director or enemy debug button in this map. The player's pistol is disabled locally. Other scenes and production combat logic are unchanged.

## Grass distribution

Default: **400 rendered patch instances**, **19,600 blades**, **117,600 grass triangles** across the entire map. They are grouped into 16 `MultiMeshInstance3D` chunks sharing one mesh/material. Patch coverage starts at **25%**, with seed **8055**. Seeded Fisher-Yates selection prevents duplicate cell selection, followed by small position jitter, random rotation and 0.94–1.06 height scaling. Bases remain exactly at Y=1. A clear center and outer margin keep grass out of spawn and beyond the map.

Scene Inspector exports: `grass_coverage`, `grass_seed`, `grass_instance_count`, `wind_direction`, `wind_strength`. Instance count −1 derives from coverage, 0 disables grass, and a positive value overrides coverage. Counts above the eligible interior cells are capped to preserve spawn and border clearance.

## Wind and interaction

`materials/grassland_grass.gdshader` is the sole grass animation writer. Every patch shares the same direction, strength and four-second phase, with small world-space phase / instance amplitude variation. Authored bend masks anchor roots and increase bending toward tips. World displacement is converted through each rotated instance basis, so rotations do not rotate the wind. Small vertical shortening and a 11.5 cm combined cap keep the bend restrained.

`scripts/grassland_motion.gd` publishes eight bounded recent movement segments: world positions, movement-derived direction/strength, birth age and last-motion age. Each blade decodes its own root UV2 and evaluates distance to the recent path, with smooth radius falloff to zero at **0.65 m**. It receives outward push plus some movement push. Smooth attack and an **0.8 s recovery** envelope preserve follow-through after passage. Stationary players add no samples. Reversals freeze the old path and start a fresh attack. Full history retains recovering samples until they expire; extremely rapid alternating turns may temporarily defer a new sample rather than snap an old trail away.

Walking at the unchanged **4.25 m/s** uses a nominal **5 cm** tip strength and **0.14 s** attack. Sprinting at **6.25 m/s** uses **9 cm** and **0.07 s** attack; intermediate actual speeds blend smoothly. GPU readback at the tested path center measures roughly **4.6 cm walking** and **8.4 cm sprinting** after soft direction normalization. Wind adds to both.

Only three shared uniform updates occur per physics tick: phase and two eight-element arrays. No per-grass scripts, colliders, physics, AnimationPlayers or CPU vertex deformation are used. Grass is opaque/two-sided with no alpha cards or grass shadows. Chunks have a conservative bend culling margin.

References for the engine interfaces: [spatial shader built-ins](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html), [MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html), and [render timing API](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-set-measure-render-time).

## Validation and performance

- `tests/validate_grassland.gd`: 3,031 passing checks of actual rendered cell geometry/area, collision dimensions, imported geometry/masks/UV2, 400 instances, seed reproducibility, configuration, real controller/input, traversal, corner/seam collision, bounded trails and enemy absence. An imported-mesh check caught and corrected glTF's UV V flip in blade-root lookup.
- `tests/validate_grassland_motion.gd`: 308 passing checks, including actual controller reversal frames, preservation of old paths, smooth fresh attack, stopping and rapid-turn history saturation. The reversal regression failed before the fix.
- `tests/validate_grassland_shader.gd`: 21 passing checks, production vertex shader executed on the GPU with test-only readback output. It checks planted roots, subtle wind, height weighting, rotated-world coherence, wind seam, walking/sprint strength and attack, outward/sideways response, far isolation, direction-cancellation continuity, additive effects and complete recovery. The cancellation regression failed before the fix.
- `tests/review_grassland.gd`: ten rendered captures of standing wind, next wind phase, walking forward/sideways, sprint, rapid reversal, stopping, recovery, boundary sides and detail. Captures are in `game_mobile_3d/.validation/grassland_review/`.
- Current production `validate_r15_strafe.gd`: **7,217 checks, zero failures**. Final Grassland runtime/test logs have no errors or warnings.

Warm desktop profile (`tests/profile_grassland.gd`): Godot 4.7.2 Mobile renderer, Direct3D 12, RTX 4070 Ti SUPER, 1280 × 720, uncapped rendering, no screenshot readback in the sample window. Final mean CPU frame times: **2.366 ms idle**, **2.444 ms sprint**, **3.798 ms whole-map overview**. Draw calls: **37** at spawn, **37–38** during sprint, **44** with the whole map visible. Whole-map primitives: **133,616**, including player/UI/shadow passes. Raw render timer counters are saved in the profile; they are not a portable phone GPU performance estimate. Cold/capture-loop timing is excluded from these claims. Android/iOS hardware was not available for measurement.

The workstation lacks the Vulkan surface extension; explicit D3D12 launch avoids a fallback error while retaining Mobile rendering. No project-wide rendering method was changed.

The existing 20-suite legacy runner was also executed before changing the launch scene. **7 suites passed cleanly; 13 had existing failures/errors in the unchanged production baseline.** This is not a green full legacy suite. Current player assets/controller/camera/gameplay scripts were identical to the original checkout for that run; the additive E1 files are not referenced by those older scenes.

Clean: `locomotion_stop`, `movement_weapons`, `weapon_carry_c1`, `weapon_select`, `combat`, `bounce_animation`, `player_pose_lab`.

Failures/errors: `animation_v2` (5), `blocky_v7_integration` (2), `weapon_behavior_d0` (16), `holster_d2` (80), `holster_d2_live` (10), `draw_d5` (315), `draw_d5_live` (8), `weapon_sprint_d3` (11), `back_carry_d31` (392), `back_carry_d31_live` (20), `living_ready_e3` (193 logged errors despite exit 0), `ready_e3_live` (4), `gameplay` (1). Examples include old per-weapon-scale/hand-contact checks and old authored-run expectations against the current R15 player. These historical animation/combat fixture issues remain outside E1. Logs and the suite summary are under `.validation/locomotion_r6p/grassland_e1_*`.

A separate read-only code reviewer found the reversal continuity defect; it was fixed with failing-to-passing regression evidence. No other actionable findings were reported. Artistic judgment, arbitrary whole-scene scaling, coverage beyond the intended range, and physical-device performance were set aside: current identity scale and patch X/Z scales satisfy the shader, count caps preserve clearance, and human/device review is still required.

## Files and rollback

Created: exporter, source exports/atlas/manifest/import metadata under `assets/environment/grassland/`; `scenes/Grassland.tscn`; `scripts/grassland.gd`; `scripts/grassland_motion.gd`; `materials/grassland_grass.gdshader`; four validation/review scripts plus `tests/profile_grassland.gd`; Godot UID sidecars; this report; `docs/superpowers/plans/2026-10-08-grassland-e1.md`; `scripts/launch_grassland.ps1`. Local captures, profile and logs are in ignored `.validation` directories.

Modified existing file: **`game_mobile_3d/project.godot`**, one `run/main_scene` line selecting Grassland for immediate review. Previous `scenes/CuboidGameplayTest.tscn` remains intact. Restore that main-scene value or launch that scene explicitly to return to the previous game. No player, gameplay/combat or original Blender asset was modified for E1. Concurrent unrelated R14 Blender work is preserved.

Launch from repository root: `powershell -File scripts/launch_grassland.ps1`. It opens the normal game, without a validation harness. **WASD** move, **Shift** sprint, **R** return to center. Walking off an open outer edge respawns the player at center after falling; the boundary is not fenced.

## Human review remaining

Review grass color under the game's existing lighting, 49-blade patch density/pattern, height relative to the player, subtle wind visibility at the production camera distance, walking/sprint bend and recovery timing, and foot sliding from the existing animations. Automated captures/readback and scripted controls are evidence, not human artistic approval. The map is playable; no trees, flowers, rocks, enemies, weather or other biomes were added.

**ARTISTIC STATUS: AWAITING HUMAN REVIEW.**
