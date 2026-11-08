# Terrain material and spatial light implementation

> Execution: superpowers:executing-plans, inline with a fresh final review.

**Goal:** User-approved terrain PBR preservation plus colored, position-dependent indirect lighting in the existing F5 WorldMap.

**Spec:** The latest user approves the priorities in private `terrain_light_audit_v001/README.md`. MD2 measured terrain uses linear MRE, specular .5 and spatial incoming diffuse/reflection; these inform semantic composition, not copied radiance arrays. Keep original GAF atlas/UV/grade/roughness when no source map exists. No Valorie skin roughness or self-light on terrain.

**Architecture:** Existing Look remains material owner. A strict source-PBR binder updates original terrain adapters and cutaway copies. A scene-local cache manager installs additional transient per-vertex irradiance attributes on generated meshes, preserving authored arrays/indices/collisions. An offline original voxel integrator reuses the current solid-half-cell representation, integrating directional sky visibility and colored single-bounce sunlight. Original color-aware diffuse multibounce approximation is explicitly separate from exact MD2 composition. Shader variants replace terrain ambient only and suppress overlapping old mineral bounce/visibility. Approved player/grass/environment owners remain untouched.

**Tech:** Godot4.7.2 Mobile, GDScript/spatial shaders, existing Python/NumPy authoring tools; original GAF `.res` cache. No new scenes/projects, tools, source extraction or captures.

## Constraints and review focus

- All MD2 proprietary inputs remain external/private/ignored. Cache uses original map/colors only; no native bytecode or source arrays in Git.
- Keep player Combined default, grass wind/splay/light/density, camera/gameplay/animations, audio OFF, global light/exposure unchanged.
- Day/current layout/direction/ambient-owner guard; baseline B, unsupported renderer/settings/cache mismatch and disabled mode restore prior shaders/material values.
- No overlapping ground-bounce or optional F12 visibility when spatial field is active. Preserve preceding comparisons when it is OFF.
- Cache validates complete coverage, signatures, lengths and finite values before atomic mesh replacement. Shared vertices/normals must agree; no mutation of source GLBs or scene collisions.
- Mobile: six additional floats/vertex, interpolation, no fragment ray tracing or additional render pass. Actual device budgets remain unverified.

## Tasks

- [x] RED adapter and spatial contracts plus integrator tests (open sky, occlusion, colored reflection, sun shadow, invalid input).
- [x] Implement and validate original integrator/export/packing; bake source geometry and scene-owned albedo means. Validate convergence and independent ray checks.
- [x] Complete source PBR/channel/texture/emission binder under Look; reject unsupported source behavior, retain previous recipe OFF; cutaway parity.
- [x] Install guarded cache and terrain-only shader composition. Keep old ambient/ground bounce available via master OFF, avoid double counting.
- [x] Add existing L controls for previous/material-only/lighting-only/combined. Default combined after validation.
- [x] Native locked before/after/restore, ambient-only/sun-off, cutaway transitions, gameplay and protected player/grass checks; GPU/draw/memory measurements with desktop limits.
- [x] Fresh review, documentation, Git-safe commit/push and final scene review.

## Ledger

- User explicitly approved implementation. Work stays on existing main per AGENTS; no new checkout or project.
- Local radiance generation remains an original mobile approximation, not recovered Lumen. Source roughness texture absence is retained rather than inventing a universal roughness value.

- Review found missing normalization and world-transform guards; fixed with rejection/move/restore tests and metadata-v2 export. Existing baked arrays were reused after byte-identical transport-input verification.
- Native1812 checks, Python5, HDR7(max9.77e-5), prior ground-bounce17/terrain-sky535 tests pass. SourceRun7m/s retained; render30 variation matches repeat-control. Cross-checkpoint small raster residuals are disclosed, not tuned away.
