# Terrain colored contact implementation plan

> For agentic workers: use superpowers:executing-plans inline. User requested direct implementation in the existing main map.

**Goal:** Apply the source-backed indirect color response in the playable WorldMap while preserving an exact previous-mode comparison.

**Architecture:** Keep the existing authored spatial RGB transport, source material adapter and hard voxel normals. A bounded local-contact proxy feeds an independently expressed colored visibility response; it modulates indirect diffuse only. Stop applying that artistic proxy to direct light in the new mode; real shadow attenuation is unchanged. This is not native bent-normal generation or Lumen.

**Tech stack:** Existing Godot Mobile shaders, GDScript, native HDR/readback fixtures. No dependency or new scene.

**Spec / authorization:** Current user request to apply the completed Forest terrain findings directly to main gameplay. Relevant evidence is private `forest_location_lighting_v001`; no source assets/code/bytecode enter this repo.

## Constraints and approach

- Retain current cache, geometry, UVs, material maps, source roughness/specular, grass, player, camera, fog and sound-off.
- Do not stack another ambient field or copy material values from unrelated native pixels.
- Reuse existing terrain owner and bind the comparison uniform to opaque AND cutaway materials.
- Keep previous terrain transport behavior selectable, including contact-to-direct behavior.
- Work in existing main checkout as explicitly required by AGENTS; preserve pre-existing generated import-file change.
- Alternative of new Lumen/bent-normal caches deferred: generation is not recovered and existing lighting already works. Alternative of a global ambient boost rejected: it erases spatial depth.

## Review focus

1. Cutaway created after toggling must inherit the response.
2. B, F12, unsupported renderers and unavailable transport retain prior guards.
3. Zero radiance stays black; contact does not change base color/emission/metallic response.
4. Direct sunlight remains shadowed; only the original artificial local-contact multiplier is removed.
5. Day/night use their existing source-direction guards; never reuse mismatched cached sun.

## Task 1 — Scoped response and main-map integration

- [x] Add failing WorldMap contract test for response control, defaults and cutaway propagation; run it.
- [x] Add original colored visibility helper and reversible branch in existing transport include; use it from ground/cutaway shaders.
- [x] Bind the requested mode through existing terrain transport owner and add one comparison checkbox in existing L panel.
- [x] Run native/headless terrain, showcase, player/grass checks; numerical HDR cases compare an independent CPU model and actual production helper.

## Task 2 — Visual and performance gate

- [x] Capture identical-camera previous/new/restore at cliff, west and meadow, with fixed pose/time/wind.
- [x] Inspect visible changes; require exact previous restores, no geometry/pass/draw expansion and no material or gameplay changes.
- [x] Measure warm ABBA viewport timings on Mobile; disclose shared desktop load and lack of phone certification.
- [x] Document mappings/limits and open the existing F5 WorldMap for review. No new scene or broad fog/post-processing changes.

Ruling: use the existing local geometric contact as a declared visibility proxy; do not claim recovered bent normals. Existing longer-range transport is not regenerated or multiplied by another whole-sky field. User requested inline implementation in the existing main checkout; no worktree, new scene or additional approval gate was introduced.

Review: fresh read-only reviewer found no blockers in the scoped shader/owner/cutaway changes. Private evidence retains rejected initial camera/HDR fixture attempts. Full results and boundaries are in TERRAIN_COLOR_RESPONSE.md.
