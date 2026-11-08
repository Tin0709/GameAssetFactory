# Environment light composition implementation plan

> Implement inline using executing-plans; user explicitly authorized adding recovered research to existing main gameplay. Preserve previous configurations and private assets.

**Goal:** Expand actual block lighting and spatial atmosphere in F5 WorldMap, retaining approved player/gameplay and prior atmosphere density.
**Architecture:** Original GGX BRDF integration LUT and diffuse-field specular proxy on canonical nonmetal GAF terrain; independent dielectric-response switch. Source effective linear Forest scatter chromaticity stays private/hash-gated and preserves original medium luminance. Original baked sun visibility modulates inscatter using recovered square/occlusion-floor math; extinction unchanged.
**Spec:** Existing forest_location_lighting_v001, forest_humidity_light_v002 and user's apply-additional-effects instruction.

## Constraints and evidence boundary
- Work in existing main checkout, no new scene/project/assets replacement/controller/camera change. Preserve pre-existing mist-import EOF change.
- Do not claim Lumen, native reflections or full volumetric reconstruction. Six-axis terrain irradiance is a radiance PROXY; GGX consumer form recovered, LUT independently integrated.
- Canonical authored nonmetal terrain uses an explicit source-motivated dielectric response; source material parameters remain unchanged. Preserve roughness/maps/emission/UVs/colors.
- Air source color is effective Day coefficient, not generic all-biome data. Blend over the existing original phase schedule; Night endpoint retains old color.
- Original sun-visibility field replaces native radial/screen-space producer, which cannot be copied into the current orthographic rig. Recovered finish core is .2+.8*v*v; no claim of identical screen-space mask. Guard exact static map/recipe/sun orientation, then multiply INSCATTER only.
- No density or uniform blur increase. Existing common surface FOG path, opaque/cutaway/grass/player parity and F7 compositor ownership must hold.
- Proprietary source/calibration stays private and ignored. Only original integrator/LUT/visibility data enter Git.

## Work
- [x] Red tests for own BRDF integration, medium/terrain controls and source boundaries.
- [x] Implement/bake original LUT and static sun visibility from existing original GAF exporter data.
- [x] Integrate reversible terrain and linear/scatter-light effects, lifecycle/fallback/late-cutaway support.
- [x] Validate HDR numerical equivalents, source profile guards, native/fallback regressions, same-camera Day/Night/moving checks and desktop Mobile performance. Correct defects.
- [x] Fresh review, docs/checkpoint and normal main gameplay opened; commit/push existing configured main after checks.

Execution evidence: docs/graphics/unified_showcase_v001/ENVIRONMENT_LIGHT_COMPOSITION.md. Fresh native2404/Compatibility/headless pass; source and shader regression fixtures preserved privately. Mainline commit/push and interactive launch are recorded in the private handoff.
