# Terrain colored contact response

2026-11-08. User authorized direct main-game integration after the Forest GPU study. F5 still opens `res://scenes/WorldMap.tscn` with the existing player and graphics. No new scene, asset, cache, texture, renderer or post-processing pass.

## Current default and comparison

The existing local RGB terrain transport stays active. **L → Terrain · colored corner response** defaults ON. Turn it OFF to inspect the preceding local-transport/contact treatment. The existing TERRAIN picker and B baseline retain their meanings; F12 still replaces, rather than stacks with, local transport. In unsupported rendering/lighting contexts the preceding fallback remains.

The new response sends the existing authored short-range contact proxy through an independently expressed color-aware indirect visibility fit. Indirect diffuse can retain warm/cool material-dependent color instead of using a gray response. The proxy no longer artificially multiplies direct diffuse/specular; actual shadow `ATTENUATION`, light direction, GGX, cloud attenuation, and material channels are unchanged. Opaque and transparent cutaway terrain use the same helper and inherit the comparison setting, including materials created after a toggle.

## Evidence boundary

The Forest capture verifies the indirect composition algorithm and its color-aware visibility term, not a complete replacement for Lumen. Existing GAF spatial irradiance remains original map-derived data. Its local contact proxy comes from authored geometry-distance rules, **not** native bent-normal generation. This adaptation is consequently an original Mobile approximation informed by recovered behavior. Native pixel roughness values are not assigned to unrelated GAF blocks; authored maps/specular/emission remain intact.

Existing broad visibility and one-bounce transport are retained, not baked again. The added local term represents the current short contact footprint, not another full sky-occlusion pass. Canopy visibility, spatial RGB, material reflectance, direct shadows and final atmosphere remain separately owned. Exact native short-range occlusion parity is unresolved.

## Validation

- Headless contract: response6 / terrain1946 / showcase25 clips; native Mobile/D3D12: response4790 / terrain1959 / showcase25 clips, no failures.
- Actual production include,24 independent CPU-versus-GPU HDR cases: max absolute error8.3894e-6; zero reflectance/occlusion and metallic diffuse-zero cases included.
- Three locked Day viewpoints and two Morning/Night viewpoints: Previous→new→Previous restores exactly0 image bytes. Terrain/camera/pose/weather are frozen per set. Initial incorrectly registered camera samples are archived and excluded.
- Day whole-frame MAE: cliff0.091 / west0.672 / meadow0.0023 byte. Local maxima27/28/3 bytes; the open meadow intentionally changes little. These metrics prove the effect is scoped, not artistic approval or MD2 parity.
- Actual movement/jump/reversal/held combo at render caps30/60/120 and physics60: no excess trajectory difference over repeat-control noise. At30 the feature and repeat residual are both0.130486mm;60/120 exactly0. Configured run speed remains7m/s; route peaks include existing jump/combat movement and are not ordinary-run speed measurements.
- Shared-desktop RTX4070TiSUPER Mobile/D3D12 ABBA viewport medians: previous0.589/0.593ms; new0.611/0.598ms, reported total133draws in all passes. Approximate median delta+0.0135ms, with concurrent MD2/desktop workload; not a clean causal benchmark or phone certification.

Player, source animations, Sabre, grass/wind/interactions, world geometry/cache, lighting phase profiles, fog and mute defaults are preserved. No proprietary data or compiled code was added to the repository. Art review and real-phone performance remain open.

## Resume / test

Open the existing project and press F5, or run repository-root `Open World Map.cmd`. Use L for the comparison above; H/T retain fog and phase controls. Tests:

```
<godot> --path game_mobile_3d --rendering-method mobile --rendering-driver d3d12 --audio-driver Dummy --script res://tests/validate_world_map_terrain_response.gd
<godot> --path game_mobile_3d --rendering-method mobile --rendering-driver d3d12 --audio-driver Dummy --script res://tests/validate_world_map_terrain_response_hdr.gd
```

The HDR test explicitly skips when no native rendering device is available. Private screenshots, GPU results, rejected fixtures, before-file copies and gameplay logs are under `MD2 Research/godot_lab/world_map_unified_showcase_v001/terrain_response_v001/`. The corresponding native Forest source evidence remains in sibling `forest_location_lighting_v001/`.
