# Terrain and atmosphere composition

2026-11-08. User-authorized additions to the existing F5 WorldMap. Default ON
for review, not a declaration of MD2 parity or artistic approval.

## What changed

- Canonical nonmetal terrain now has broad indirect dielectric reflection,
  evaluated with an independently integrated GGX split-sum LUT. Existing source
  roughness, metallic, specular, maps, emission, UVs and geometry remain intact.
  Source specular takes precedence; the .04 dielectric fallback applies only
  where the source declares zero. Most installed materials already declare .5.
- The existing spatial medium can use the effective **linear** Forest Day
  scatter chromaticity derived from eight captured shader evaluations. It is
  normalized to the previous medium's luminance: no density/intensity boost or
  second sRGB conversion. Source calibration stays external and hash-verified.
- Original GAF baked sun visibility controls only inscattered light. The
  recovered finish core `.2 + .8 * visibility * visibility` darkens scattered
  illumination in shade; it does not modify optical depth or transmittance.

This complements the already integrated colored terrain diffuse transport,
soft contact response, player local-light/material treatment, common spatial
fog, grass lighting and wind. Camera, gameplay, animations, audio-off, existing
post-processing and dense grass population are unchanged. There is no new
fullscreen blur or ground wetness/material roughness change.

## Controls and restoration

Run `game_mobile_3d/scenes/WorldMap.tscn` with F5. Press **L** for options:

- **Terrain · soft dielectric / reflected light**
- **Air · captured Forest scatter color**
- **Air · terrain-shadowed scattering**

All three OFF restores the preceding graphics treatment. **B** retains the
older full baseline; **H** isolates atmosphere and **T** retains time options.
The terrain reflection addition operates in the existing Combined terrain
mode. Incompatible renderer/map/material recipe/sun direction falls back;
Night does not reuse the baked Day shadow direction. Missing private color
calibration retains the previous color. The shadow texture RID remains stable
across OFF/ON and phase changes, avoiding volume reallocation flashes.

## Exact evidence versus independent reconstruction

The Forest capture is `forest-deep-dark-entrance-day.wpix`, SHA256
`2869d18d3ec67285968a8340cce5b5a0be7c24ca8540761b15a7f832faa05b5f`.
The private effective scatter coefficient comes from the captured shader's
actual bound data, evaluated at diagnostic depths; native D32 was inaccessible.
Thus its chromaticity is supported, not a measurement of every scene ray.

The square/floor operation and separation of RGB inscatter from transmittance
are recovered. Its **producer is different** here: original world-space static
sun visibility replaces the native radial/screen-space mask. We do not claim
native light shafts, exact native mask range, dynamic occlusion or Lumen.

The rough-reflection consumer is source-motivated. Its LUT is independently
integrated; the diffuse transport field is a low-frequency incident-radiance
proxy, not recovered MD2 specular radiance. This produces broad response on
rough blocks rather than sharp reflections. The coarse static sun grid can
leak near thin geometry and ignores moving occluders. Night GPU equivalence,
native SSS history, exact reflections and full Niagara temporal recovery remain
outside this implementation.

## Implementation / data

- `scripts/graphics/environment_light.py`: original GGX integration and static
  visibility baker using only the existing GAF authoring export/grid.
- `game_mobile_3d/assets/graphics/world_map_air_light_v001/`: original 64x64 RG16F
  BRDF LUT and 11160-probe R8 sun field; about16KB compressed on disk.
- `world_map_terrain_transport.gdshaderinc`: original incident/reflection model;
  opaque and cutaway variants share it, including late-created cutaways.
- `world_map_air_light.gd`: source hash/context guards, static field ownership,
  Day-only color transfer normalized to existing brightness.
- `world_map_mist_field.glsl`: existing shared volume adds one trilinear field
  sample per integration step; no extra volume or pass. The new UBO is224bytes.
- `world_map_atmosphere_volume.gd` and showcase publish the same medium to
  terrain, cutaway, player and grass; existing F7 ownership/failure fallback stays.

Only original code/LUT/visibility enter Git. Private calibration, references,
models, textures, captures and comparison images remain in MD2 Research.

## Verification

- Python:3 new integrator/visibility tests plus13 existing terrain tests pass.
- Native Mobile:2404 integration contracts, player39/material63, showcase25,
  terrain4790/light1959, grass, Forest atmosphere and shared mist pass.
- Headless and Compatibility retain gameplay/fallback; native-only effects are
  not asserted as rendering on unsupported paths.
- Production terrain HDR:12 cases, max absolute error4.8832e-5 versus independent
  equations. Source specular0/.5/.8 and opaque/cutaway paths covered.
- Shared mist HDR:54 samples, max error.0007124, opaque/cutaway parity.0002441.
  Six8192-voxel buffers preserve transmittance half-bits across shadow changes
  within each camera; native-fog restoration error0.
- Three locked cameras,18 images: previous/isolated effects/combined/restored.
  Restored frames match exactly. Combined mean changes .54/.82/1.13 RGB codes
  at cliff/west/meadow: a restrained composition change, not a major restyle.
- Existing controller movement/jump/reversal/combo at render30/60/120Hz,
  physics60: no discrepancy beyond repeat-control noise (.1305mm at30Hz;
  zero60/120). Speed7m/s and source animations remain.
- Shared RTX4070TiSUPER Mobile/D3D12,1280x720,6 alternating blocks,64 warm +96
  samples each: GPU medians .367-.368ms OFF/.371-.372ms ON,86 draws unchanged.
  Forced medium publication35-44us medians. These are desktop observations,
  not causal isolated GPU cost, worst-case whole-map cost or phone certification.
- Fresh focused review found no actionable important defects.

Private reproducer scripts, logs, before snapshots, source calibration and
screenshots: `MD2 Research/godot_lab/world_map_unified_showcase_v001/environment_light_integration_v002/`.
Next: user visual review, real handset measurements, then targeted correction
of any visible mismatch. Do not invent additional haze or claim engine parity
from these implementation tests.
