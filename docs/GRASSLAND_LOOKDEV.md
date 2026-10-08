# Grassland look-dev review

ARTISTIC STATUS: AWAITING HUMAN REVIEW.

This is a separate real-game review scene. `project.godot`, `Grassland.tscn`, the original environment, terrain/grass shader, approved Blender assets, production player/controller and previous launcher are not changed by this pass. The 40 × 40 block map, 400 seeded grass patches, 49 blades per patch, collision and gameplay camera remain the base. No enemies or props are added. A concurrent change added a combat-review toggle to the base map; this derived review overrides that toggle with a no-op, keeping both F7 and `--combat-review` enemy-free without modifying the base.

## Review

Run `powershell -ExecutionPolicy Bypass -File scripts/launch_grassland_lookdev.ps1` from the repository, or run `res://scenes/GrasslandLookDev.tscn` in Godot. The launcher opens the Mobile renderer with D3D12 on this workstation and writes `.validation/grassland_lookdev_live.log`. Production main-scene selection stays unchanged.

- **F1:** actual original look, including original motion, materials, environment and sun settings.
- **F2:** new look, with the selected quality.
- **Tab:** current/new A/B at the same player position and camera.
- **F3:** mobile/high review. This setting is remembered while viewing current; it affects only the new look.
- **WASD / Shift:** existing movement / sprint. **R:** existing return to center.

Starts in **NEW / MOBILE**. Inspect the standing player, walk and sprint through clusters, stop to see recovery, then visit an outer corner for dirt-side contrast. High review adds real double-sided blade shadows. Current restores the original shader and therefore the original smaller wind and interaction.

## Created files

| File | Purpose |
| --- | --- |
| `game_mobile_3d/scenes/GrasslandLookDev.tscn` | Inherits the original map and player scene |
| `game_mobile_3d/scripts/grassland_lookdev.gd` | Scene-local resources, lighting, reversible A/B, quality, one-time root shade texture |
| `game_mobile_3d/materials/lookdev_grass.gdshader` | Two-sided grass shading, darker meadow palette, stronger review wind and player splay |
| `game_mobile_3d/materials/lookdev_terrain.gdshader` | Ground palette, softer pixel texture contrast, cheap cluster/player contact |
| `game_mobile_3d/tests/validate_grassland_lookdev.gd` | Real controller, resource isolation, repeated A/B restoration, culling/shadow checks |
| `game_mobile_3d/tests/validate_grassland_lookdev_shader.gd` | Actual GPU displacement comparison with original shader |
| `game_mobile_3d/tests/review_grassland_lookdev.gd` | Matched current/mobile/high captures using real movement |
| `game_mobile_3d/tests/profile_grassland_lookdev.gd` | Serial warm profiling without screenshot readback |
| `scripts/launch_grassland_lookdev.ps1` | Visible interactive review launcher |
| `docs/GRASSLAND_LOOKDEV.md` | Review instructions, decisions and evidence |

## Artistic treatment

Warm key light now comes from rotation **−48°, −42°**, with energy **1.25** and color **(1, .88, .69)**. A cooler blue fill at energy **.60** keeps the player and shaded grass readable. The treatment retains facet contrast and matte materials.

The final user steering requested **darker grass-block tops and blades**, **stronger wind**, and **wider player splay**. The new materials use deeper meadow greens with restrained warm olive highlights. Shared broad world-position color variation links grass to the ground; gentle per-patch variation reduces uniformity. Terrain atlas speckle contrast is compressed by 65% toward a darker base while preserving its pixel shapes. Dirt sides receive a restrained cool earth tint.

Grass lighting runs per fragment and handles both sides with an upward normal bias. Root-to-tip value variation grounds darker roots and lets tips catch light. This avoids the original nearly black vertical stamps while keeping the final palette darker than the early lime iteration. Source geometry and UV2 root mapping remain intact.

The original continuous wind/path algorithm, soft normalization, quadratic root mask, arc shortening and **0.8 second recovery** remain. The new review shader multiplies wind by **3**, player bend by **1.85**, expands influence from **.65 to .90 m**, and caps combined horizontal displacement at **.20 m**. New culling margin is **.24 m**; current restores **.15 m**. The original source shader and tracker remain unchanged.

## Shadows and contact

The player retains real directional shadows, with bias **.025**, normal bias **.65**, opacity **.84**, and scene-local shadow blur **.30**. Reducing blur cleaned up the visible stipple in close captures. The light remains orthogonal and uses the existing project shadow atlas/filter settings. The stored maximum distance is **29 m**, but Godot ignores that range with this orthographic gameplay camera; the unchanged camera far plane remains **60 m**, and that distance is not a measured cost optimization. No global renderer quality state is changed.

Mobile uses a **512² single-channel** shade texture baked once from the actual seeded patch centers: about **256 KiB**, one additional terrain sample and no transparent grounding quads or per-patch lights. A small procedural ellipse under the player supplies contact close to the feet. These are stylized color-darkening approximations, so they do not respond to sun direction or grass deformation. Their world positions are stable.

High review adds actual double-sided grass shadow casting, using the same moving vertices. It improves cast-shadow shapes and blade overlap at extra shadow-pass cost. Flat terrain retains its original no-cast state: enabling casts on its tiny source bevels produced self-shadow artifacts without useful visual benefit.

## Atmosphere and post-processing

Traditional fog is lighter and subtler: density **.0035**, muted blue-gray tint, no sun scatter, and no volumetric fog. A blue-gray background replaces the dark void at visible map edges. Linear tonemapping is retained after rendered Filmic experiments produced an excessive yellow/bright wash. There is no bloom, SSAO, SSIL, SDFGI, SSR or expensive full-screen grading.

Godot documents the [Mobile renderer's supported features](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html), [two-sided spatial shader inputs](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html), and [scene-local light shadow blur/bias](https://docs.godotengine.org/en/4.7/classes/class_light3d.html). The choices above use those supported controls; artistic judgments came from the rendered game pixels.

## Evidence and performance

Final clean validation passed **434 scene/A-B/controller checks**, **3031 original map checks**, **308 original motion checks**, **21 original GPU shader checks**, and **11 new GPU shader checks**. The look-dev contract also passes with `--combat-review`, and its direct toggle/F7 paths remain enemy-free. `.validation/grassland_lookdev` contains **27 matched images**: standing, walking, sprinting, boundary, detail, player-splay and wind-phase views. Simulation is frozen only across each current/mobile/high triplet, so comparison camera/pose/phase agree. Screenshot FPS includes startup and GPU readback costs and must not be used as a performance measurement; capture HUD FPS is hidden.

GPU displacement comparison passed **11 checks** after a recorded failing run: peak-phase wind **.0152 → .0472 m**, walking bend **.0472 → .0848 m**, combined cap measured **.1967 m**. Roots, wider radius, distant rejection, lower-ring masks, cancellation continuity, soft recovery and arc length passed.

Serial warm desktop runs used Godot **4.7.2 Mobile / D3D12**, **1280 × 720**, RTX **4070 Ti SUPER**, no VSync, **3 seconds startup warmup**, separate warmups for movement/overview, and **3-second real-time sampling windows**. No image readbacks occurred during profiling.

| View / median | Current | New mobile | New high |
| --- | ---: | ---: | ---: |
| Idle CPU process, ms | 1.343 | 1.121 | 1.124 |
| Idle measured render GPU, ms | .108 | .095 | .103 |
| Idle draw calls | 39 | 39 | 53 |
| Sprint CPU process, ms | 1.117 | 1.198 | 1.219 |
| Sprint measured render GPU, ms | .105 | .108 | .109 |
| Full-map CPU process, ms | 1.135 | 1.254 | 1.096 |
| Full-map measured render GPU, ms | .094 | .099 | .102 |
| Full-map draw calls | 46 | 46 | 62 |
| Full-map rendered primitives including shadows | 133,904 | 133,868 | 251,492 |

These desktop results show unchanged mobile draw-call counts and the high option's additional shadow geometry; they do not predict phone performance. CPU samples were noisy: current sprint p95 **7.465 ms**, mobile idle p95 **15.774 ms**, mobile sprint p95 **8.137 ms**, high sprint p95 **7.683 ms**. `Performance.TIME_PROCESS` refreshes once per second and is not a per-frame histogram; the underlying means/p95 and measured render timings are preserved in `.validation/lookdev_profile_current.json`, `_mobile.json`, and `_high.json`. The sub-millisecond desktop GPU times and variability make percentage speed claims inappropriate. No catastrophic rendering cost is evident here, but target-device profiling remains necessary.

## Mobile tradeoffs and remaining limits

Mobile keeps the same terrain/grass population and adds no grass shadow pass. The two-sided fragment shading is more work per grass pixel than the original vertex lighting, while the root mask adds a small sampled texture. High review repeats grass geometry in shadow passes and should remain optional until phone measurements justify it.

This is still a flat map with one grass-patch mesh and one atlas. The reference's varied elevations, props, paths and flowers provide composition that lighting alone cannot reproduce; they were outside this pass. Repeated cluster silhouettes and source pixel patterns remain. The orthographic camera and flat ground limit distance-fog depth cues. Some thin blades and low-resolution shadow edges remain aliased, especially close up; no global anti-aliasing or atlas change is made. The baked root shade and player contact are approximations rather than physical occlusion. Android/iOS thermal, GPU, memory and battery validation remains pending. Human approval is required before any production adoption.
