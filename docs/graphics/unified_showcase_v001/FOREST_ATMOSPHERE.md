# Forest entrance atmosphere / shared spatial mist

Scope: existing `game_mobile_3d/scenes/WorldMap.tscn`, F5. This is an independently authored Mobile atmosphere adapter, not a recovered Unreal volumetric renderer or MD2-quality approval. Approved rig, clips, controller, camera, terrain geometry/transport data,8418 grass roots, wind and interaction are retained. Test audio stays OFF.

## What was wrong

The prior depth ramp applied nearly equal haze across the mostly flat orthographic gameplay view. Scattering brightness then washed out contrast. The subsequent screen-copy experiment additionally missed ALPHA/cutaway terrain: Godot captures opaque scene color before transparent rendering. The reported grass/stone mismatch was a pipeline coverage error, not simply a fog-color problem. The rejected screen prototype and all intermediate images are preserved privately.

## Current implementation

- `world_map_showcase.gd` remains the only time/light/environment owner. Hash-pinned, editor-only external `appearance.private.json` supplies source-relative phase data. It does not enter exports or Git. Missing data leaves the preceding appearance available.
- `world_map_forest_atmosphere.gd` validates four phases, bounds, finite numbers, radius and file SHA. Native Unreal lux/fog/bloom values are not copied numerically into incompatible Godot units. The transfer policy, scheduling and camera adaptation are original.
- `world_map_atmosphere_volume.gd` is a Node3D, **not a fullscreen overlay**. It publishes frustum rays and world-space medium parameters late, after the camera. Its PRE_OPAQUE `world_map_mist_field.gd` effect integrates a low-resolution 3D medium once per frame.
- Original density is exponential with world height, modulated by broad, slowly advecting world-space banks. Beer-Lambert transmittance and premultiplied inscatter are stored along32 nonuniform depth slices. Scattering brightness follows current ambient/sun energy; the source-backed warm player light has a bounded original medium contribution. No player-centered clear bubble, fake focus blur or scene-color copy is used.
- `world_map_mist.gdshaderinc` samples the same medium at each surface's own view depth. Ground, transparent cutaway, alpha-tested private grass/flowers and rich player/Sabre materials therefore use the same atmosphere. Camera/projection guards isolate the target view.
- `GAF_SHARED_MIST` shader variants exist only while the medium is ready. Inactive materials restore the exact base shader resource and native Environment fog; returning FOG=0 would **not** restore native fog. Grass lighting unwraps the atmosphere variant before its own source/restore checks.
- Resize/startup/failure readiness and reference-density fallback are decided in the late update after configuration. Borrowed compositor lists are copied with inherited environment effects retained; the existing single-camera local-exposure owner explicitly permits sharing its owned list. F7 exposure toggles coexist. Resources are freed on the render thread.
- Original spatial sky irradiance can be linearly retinted through a verified profile RGB normalization. The repaired cache is unchanged. At Night, only fixed-angular sky transport is reused; cached Day sun bounce remains zero when actual sun direction differs. Legacy F12 and the combined profile are mutually exclusive.

## Source boundary

Approved read-only native snapshot recovered28 applied groups matching **ForestA1 Day**, including sun/sky/fog/PP and20 grading vectors. Do not substitute DeepDarkMain cave presets merely because the travel label says Deep Dark Entrance. Four source phases and the8m, no-shadow warm player-light setup were recovered; intensity6 was observed in a later near-Night transition. That later snapshot is NOT an exact Night endpoint (21/28 groups match Night). No native volumetric density-generation, shadowed scattering or multiple-scattering algorithm was recovered.

Private source proof, profile compiler/transfer choices, reader provenance and snapshots are under Research `godot_lab/world_map_unified_showcase_v001/deepdark_entrance_v001`. The final pinned profile SHA is741d37edf0740caac71bae975cc715b6e42d2a0a074f4dfda54a91eb211abb5c. Mapped density/falloff, bank/noise shape, light-energy transfer, warm-light energy, bloom transfer, vignette and time schedule are ORIGINAL approximations. No proprietary shader source, assets, bytecode or captured constant buffers were copied into the project.

## Review controls

Open the existing Godot project and press F5. Day/Combined/shared spatial mist is the default when private data and Mobile RD are available.

- H: fog off/on without changing the lighting profile.
- L: options; atmosphere Previous / haze-only / lighting-only / Combined.
- L → Spatial mist: OFF shows the flat native-fog reference, ON the shared world medium.
- T or L phase buttons: Morning / Day / Golden / Night. Shift+T previews the original GAF cycle, not recovered MD2 phase durations.
- B: original graphics comparison; F7 local exposure; F12 legacy sky-only replaces the profile/local GI.
- WASD / Shift / Space / LMB or E retain the approved movement, jump and Sabre controls. Audio remains muted.

## Validation and evidence

Private `shared_comparison/` contains24 full-resolution locked-camera frames: two map sites × Morning/Day/Night × OFF/previous screen model/improved/OFF restore. Lighting, camera, pose and time are frozen per set. All six OFF→restore comparisons are byte-identical. Six contact sheets provide the requested three-way comparisons. Additional camera-yaw views and27 phase/angle cases pass. These are same-scene comparisons, not geometrically registered MD2 reference screenshots.

- Actual production shader HDR fixture:36 cases, orthographic/perspective, resize, opaque and cutaway alpha1/.5. Independent4096-sample integration reference: max channel error0.000712395; opaque/cutaway parity0.000244141. Native-fog OFF-variant restoration vs FOG-free reference: exactly0, with a nonzero fog ON/OFF signal.
- Native profile, missing/unsupported guard, H/baseline/F12 restoration, compositor coexistence and injected GPU-failure fallback pass. Headless profile/medium guards pass.
- Terrain1959 / player63 / grass lighting / source wind / showcase25-clip checks pass; Python irradiance8 tests pass.
- Existing WorldMap controlled movement/jump/reversal/combo route at render caps30/60/120, physics60: feature trajectory error0.130486mm at30, exactly equal repeat-control noise;60/120 exact0. Peak speed and clips remain recorded in `gameplay.private.json`. No controller parameters or animation curves changed.
- Warm desktop Mobile/D3D12, RTX4070TiSUPER,1280×720, shared machine: Day GPU median OFF0.303 / old screen0.369 / shared0.385ms; Night0.330 /0.398 /0.419ms. Day visible draws133→133; Night146→146. These viewport timings are NOT end-to-end phone FPS, clean isolated workload certification or a universal cost guarantee. Raw192-sample passes and hardware counters are preserved.
- Default field80×45×32 RGBA16F =921600 bytes (~0.88MiB), plus16KiB original noise; one compute dispatch, one filtered volume fetch per participating fragment. No fullscreen color-copy draw. Device storage support is checked; failure restores the native reference path.

## Limits / next review

User visual approval and real-phone power/thermal/FPS testing remain pending. This replaces the visibly mismatched screen path, but does not reproduce native shadowed volumetric lighting, shafts or full multiple scattering. Existing additive combat VFX/legacy material families are not all converted to shared FOG; inspect these separately before broadening scope. The screenshot's canopy/water/emissive forest composition is not recreated by this scoped fix. The reported white edge marks were not obvious in the final locked views, but GPU cutaway parity alone does not certify every moving MSAA/alpha edge on every device.

To resume, inspect the six comparison sheets first; launch WorldMap with H, T and L; validate on target phones before increasing volume resolution/density. Do not re-extract assets, modify approved animations, reuse Day sun transport at Night, or stack the rejected screen overlay over the shared medium.

Official behavior references: [screen-copy timing](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html), [FOG output and transparency](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html), [Mobile compositor support](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html). Native Godot volumetric fog remains Forward+-only; this is a small original Mobile effect.
