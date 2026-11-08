# GameAssetFactory graphics checkpoint

Checkpoint date:2026-11-08, Asia/Saigon. **Development is stopped at the user's
request. This is not acceptance of MD2-level visual quality. Resume only after
an explicit new instruction.** No graphics code, shader, scene, asset or setting
was changed during this documentation/preservation checkpoint.

Implementation anchor:`38da2d6c8332e078131ed104d0c0ede4427dd35b` on `main`.
This includes the terrain-sky work through `6af67694` and18Godot-generated UID
files. The checkpoint packaging commit adds documentation only; its final SHA
and remote verification are recorded in the private Research handoff/receipt.
Use `git log -1 -- GRAPHICS_HANDOFF.md` to locate this documentation revision.
Normal Git/LFS history is preserved; do not reset, clean, rewrite or force-push.

## Open the current playable scene

- Project:`C:/Users/ADMIN/Desktop/Dev/GameAssetFactory/game_mobile_3d/project.godot`.
- Main scene:`res://scenes/WorldMap.tscn`; press **F5**, or run repository-root
  `Open World Map.cmd`. F6 runs the currently selected scene and can open an old
  lab if another tab is active.
- Tested engine:Godot4.7.2, `ed1daf0bf`, Forward Mobile/D3D12 on RTX4070TiSUPER,
  normally1280x720/MSAA2x. Compatibility is a fallback, not visual parity.
- This is the original GAF WorldMap movement/graphics scene. Its current setup
  disables Combat/SpawnDirector and initially disables Pistol; this checkpoint
  does not claim a complete main-map combat release. The separate private Sabre
  research prototype and its verified7m/s controller are preserved, not replaced.
- The main-map original player uses its existing movement/JumpV004 workflow;
  its current sprint is6.25m/s. Do not apply private Sabre speed fixes to it.
- Current camera is orthographic, size14.5, rotation(-36.315886,36.869898,0),
  offset(12,15,16), gameplay far72 and extended near-8. It is not established as
  an exact match to the native MD2 perspective camera.

## Current status

| System | State | Scope and limitations |
|---|---|---|
| Original terrain, grass, flowers, ten oaks and87accent placements | Integrated | Existing approved/source assets preserved; no native MD2 assets copied |
| Day composition, balanced palette, canopy contact, oak pigment/root soil | Integrated and scoped visual tests | Default combined finish; art approval and whole-image MD2 equivalence not implied |
| Grass/flower passage and coherent crown wind | Integrated and tested | Original adapters informed by research; not complete native wind/physics recovery |
| Cutout filtering/MSAA and render interpolation | Integrated and tested | Stable source appearance/presentation; no animation retiming |
| Directional sky/ground diffuse fill | Integrated and tested | One global field, not local GI |
| Local actor crown visibility | Integrated and tested | Static macro-visibility, all ten crown slots; no colored/dynamic bounce |
| Ground-reflected sunlight on stone | Integrated and tested | Static finite-patch one-bounce approximation; current Day/source guards |
| Terrain upper-sky visibility | Experimentally integrated |535native checks plus scoped HDR/playback pass; final cross-run image equality remains unresolved |
| Local Exposure compositor | Available, optional |F7; excluded from combined default because one scout lifted shaded grass too broadly |
| Multi-biome/night/device tiers | Research/roadmap | Current WorldMap is a Day foundation; not validated as a complete multi-biome/mobile system |

Original topology:42996logical cells,67694terrain triangles. The playable border
is about100x100m, but the source field covers137x110m from(-77,-56). Do not
hardcode100x100when rebaking a source-space field.

## Architecture and file ownership

All paths below are relative to `game_mobile_3d/`.

- `scenes/WorldMap.tscn` inherits `GameplayMap.tscn`; `scripts/world_map.gd` owns
  launch/setup, original-map indexing, camera tracking and review inputs.
- `scripts/world_map_geometry.gd` builds/culls original blocks, instanced plants,
  collisions and matching opaque/camera-cutaway materials. Geometry/source
  positions, normals, UV/UV2, colors, indices and collisions remain intact.
- `scripts/world_map_look.gd` owns scene-local material variants, Day/palette
  choices, cloud/wind publication, root/contact fields and comparison restoration.
  `assets/graphics/meadow_daylight_v5/preset.tres` remains the baseline source.
- `materials/world_map_ground_v5.gdshader`, `world_map_cutaway_v5.gdshader`,
  `world_map_surface_v5.gdshaderinc`, `world_map_direct_cloud.gdshaderinc` and
  foliage/cloud/wind includes implement original GAF shading.
- `scripts/world_map_grove.gd` and original grove materials control tree reveal,
  shared wind, matching moving shadow crowns and understory placement.
- `scripts/world_map_presentation.gd` activates interpolation BEFORE static
  geometry creation, interpolates only the player root, keeps local visual poses
  direct and uses the same rendered root for camera/reveal/cutaway. Never toggle
  the global interpolation service late: a rejected prototype collapsed chunks.
- `scripts/world_map_ambient.gd` and `materials/world_map_ambient.gdshader` own a
  cached32-size original sky/ground field. Nonphysical Mobile, unit background
  energy and eligible sky/exposure bindings are required; unsupported contexts
  retain the old constant ambient. Source energy is encoded once in radiance.
- `scripts/world_map_actor_fill.gd`, `world_map_sky_probe.gd` and actor sky
  shaders use original canonical oak caches in
  `assets/graphics/world_map_actor_sky_v001/`. Keep all ten stable slots: the
  rejected top-two rank selection caused an actual walking light pop.
- `materials/world_map_ground_bounce.gdshaderinc` and
  `assets/graphics/world_map_ground_bounce_v001/normalized_ground.res` add
  original unit-sun reflected light only to vertical mineral faces. Two separate
  height-checked contributions avoid terrace-height bleeding. Current light
  color/energy applies once; this is neither emission nor full Lumen.
- `scripts/world_map_terrain_sky.gd` and
  `assets/graphics/world_map_terrain_sky_v001/visibility.res` add one R_FLOAT
  custom vertex stream to generated mineral geometry. Shader AO affects ambient
  only. Complete eligible surface coverage and exact source signatures are
  checked before atomic replacement. Original arrays are retained numerically;
  old generated meshes are released, and `look.terrain_materials` MUST reference
  replacements so B/stage switches change live materials.
- `scripts/world_map_local_exposure.gd` is the optional compositor owner. Keep
  existing ownership/restore/fallback behavior; do not make it default by accident.

All new graphics caches are original GAF-derived data. Normalized reflected
radiance and sky accessibility are static approximations; changes to original
geometry/material/shadow context can require explicit regeneration. A source-map
hash alone is not a universal fingerprint of every external dependency.

## Controls

| Key | Comparison |
|---|---|
| WASD / Shift / Space / R | Move / sprint / jump / reset |
| V / Shift+V | Overview / gameplay cliff-cutaway comparison |
| G / Shift+G | New planting / visit grove |
| N / Shift+N / Alt+N | Travelling breeze / height-aware passage / crown wind |
| B | Original/material/current look stages |
| U / F8 | Day composition / combined finish and prior selections |
| P / Shift+P | Original/balanced palette |
| F1 / Shift+F1 | Shadow filtering / reflected-ground sunlight |
| F2 / Shift+F2 | Canopy contact / oak root soil |
| F3 / F4 | Direct-only cloud shading / cloud pockets |
| Y / Shift+Y | Foliage transmission / crown pigment |
| H / Shift+H / F7 | Fog / atmosphere-depth review / optional local exposure |
| F9 / Shift+F9 | Leaf sampling / MSAA2x-versus4x |
| F10 | Render interpolation |
| F11 / Shift+F11 | Global directional fill / local actor crown visibility |
| F12 | Experimental local terrain sky visibility |

Some controls are enabled only in supported renderer/look contexts. Per-effect
requests can persist while B/profile/fallback temporarily suspends application.

## Existing validation evidence, not newly rerun at wrap-up

- Main map7094checks/394raycasts; source topology and native transform readback
  retained. Actor29, global ambient20, ground bounce17 scoped native checks pass.
- Ground bounce36HDR cases:independent analytic-model absolute error<4.685e-5;
  opaque/cutaway and zero-source controls exact. Four same-run off/restore views
  exact. Physical sprint/jump/reversal/stop paths match150shared ticks.
- Terrain sky535native,7headless/Compatibility each;60HDRcases:ambient absolute
  error2.4414e-5, sunlight differential1.2207e-4, opaque/cutaway exact. Physical
  playback positions match145shared ticks; render poses are not equal-time proof.
- Terrain quadrature512held samples:1024vs4096rays mean.000936/p95.003194/
  max.006578. Coarse triangle interpolation at512centres:mean.01384/p95.04457/
  max.27043;1.37%exceed.1. This is an approximation, not a universal pixel bound.
- Public terrain bake differs from prototype in15of50894values by at most
  5.9605e-8 due to native Color float precision. Five Python authoring tests pass.
- Actor visibility has bounded average errors but a worst held sample about.348
  near a voxel boundary. Do not describe its harmonic/max-union model as exact GI.
- Newest TerrainSky `FINAL_REVIEW` versus `REVIEW_SETTLED` whole-frame equality
  failed before pause. Cause is NOT diagnosed. Earlier within-run restoration
  and masked static-environment controls passed; those do not close this failure.
- Two source-review bugs were genuinely reproduced and fixed:detached material
  owners broke B; incomplete cache coverage could read absent CUSTOM0 as zero.
  Native535tests cover both. No new actionable defect in the follow-up review.

## Performance and outstanding quality gates

Desktop observations are not smartphone claims. Quiet directional-fill testing
at720p:GPU median.313/.323ms off/on, p95.318/.329ms, renderer CPU.150/.151ms;
448KiBextra texture residency. Clocks were not fixed, and these are scoped runs.
Ground bounce adds576KiBobserved texture residency (482240logical bytes).
Actor caches contain900000CPU coefficient bytes plus resource/temporary overhead.
Terrain sky adds203576observed GPU buffer bytes, zero new texture bytes and no
draw-call change at four views(89/25/100/131). Warm toggles do not remove caches.
One-time mesh reconstruction exists; handset loading cost is unmeasured.

Clean causal timings for the newest actor/ground/terrain systems were explicitly
deferred by the user. Runs named CLEAN_STATIC/MOVING had Cities2 present and are
NOT accepted clean. Do not infer effect cost from concurrent-game samples.
No actual handset30/60/120FPS, thermal, energy or sustained-bandwidth acceptance
exists. Device models remain unspecified. No distributable build/release-export
configuration was verified here; this checkout has no `export_presets.cfg`.

Remaining visual gaps include colored/local/multiple-bounce indirect light,
dynamic canopy/occluder transport, richer grass-ground-tree composition, final
shadow/atmosphere/color harmony and comparable whole-scene artistic acceptance.
Day/night and other biomes are not validated uniformly. MD2 is a quality
benchmark; no percentage of overall visual fidelity has been established.

## Private research and boundaries

Canonical private workspace:`C:/Users/ADMIN/Desktop/MD2 Research`.
Read its `GRAPHICS_HANDOFF.md`, `GRAPHICS_ROADMAP.md`, `GRAPHICS_PROGRESS.md`,
`EVIDENCE.md` and final checkpoint receipt before resuming. They index existing
PIX captures/DXIL, material/runtime metadata, numerical models, images, logs and
failed controls. Do not copy native shader code/bytecode, original textures,
meshes, LUTs, audio or capture inputs into this repository or builds.

`scenes/dev/MD2OverworldFidelityTest.tscn` and the private Sabre/A&S research labs
remain separate from main WorldMap. External-only research loaders/guards are
not permission to ship their source data. Do not purge existing backup history,
modify original game files, bypass protections or install tools without approval.
The paused checkpoint preserves data locally; it is not a new off-machine backup
of the approximately104.6GBprivate Research collection.

## Exact resumption sequence, after explicit authorization

1. Read root `AGENTS.md` and both handoffs; inspect current Git branch/status and
   the final checkpoint receipt. Reuse the existing checkout. Do not reset it.
2. Obtain existing LFS assets with `git lfs pull` if needed; use the recorded
   engine version. Research data must be restored separately and privately on a
   different computer. The published original WorldMap does not need MD2 assets.
3. Inspect the saved `FINAL_REVIEW`/`REVIEW_SETTLED` difference by region and
   actor timing. Do not repeat captures or assume a cache regression from the
   failed equality assertion. Record the evidence boundary honestly.
4. Run targeted tests against the FINAL public cache, then review WorldMap at
   the locked cliff/west/east/spawn views before authoring more graphics:

```
godot --path game_mobile_3d --rendering-method mobile --rendering-driver d3d12 --audio-driver Dummy --script res://tests/validate_world_map_terrain_sky.gd
godot --path game_mobile_3d --rendering-method mobile --rendering-driver d3d12 --audio-driver Dummy --script res://tests/validate_world_map.gd
python -m unittest discover -s tests -p test_terrain_sky.py -v
```

5. Preserve F12/F11/Shift+F11/Shift+F1 independence and B restoration. Do not
   rebuild approved Blender assets, rerun extraction or rebake unchanged caches.
6. Select the largest visible whole-scene mismatch at a controlled reference
   framing. Improve one reversible system at a time; compare actual playable
   images rather than optimizing isolated equations indefinitely.
7. When the user is ready, perform a genuinely quiet desktop benchmark and
   real-device30/60/120FPS/thermal validation before accepting quality tiers.

Nothing in this handoff authorizes automatic resumption or new implementation.
