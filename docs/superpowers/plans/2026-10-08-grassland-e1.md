# E1 Grassland implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task by task. Steps use checkbox syntax for tracking.

**Goal:** Deliver the requested playable 40 × 40 Grassland map in the real mobile Godot project using the latest Blender assets.

**Architecture:** Export the v3 source block and grass basis without editing the original. Combine exposed block surfaces in 10 × 10 chunks, use one ground box collider, and instance seeded grass patches. One shared material receives a wind clock and eight bounded movement segments for local blade response.

**Tech stack:** Blender 5.2, glTF, Godot 4.7.2 mobile renderer, GDScript and spatial vertex shader.

**Spec:** User's E1 request pasted in this chat; asset guidance in `blender/environment/studies/grass_block_wind_v3/README.md`.

## Constraints

- Exactly 40 × 40 cells; each source block is 1 × 1 × 1 m, top at Y=1.
- Reuse `scenes/characters/CuboidPlayer.tscn`, its controller, animations, collision and inputs.
- Preserve `CuboidGameplayTest.tscn`, combat systems and Blender sources.
- No enemies, added biomes, grass physics or per-instance animation.
- Default 25% patch coverage, reproducible seed, clear center spawn.
- Leave the actual game open after scripted rendered checks. Artistic status awaits human review.

## Review focus

- Rotated patches must still bend in the same world wind direction.
- Root UV and bend data must survive export without coloring the atlas material.
- Stationary movement samples expire; stopping and reversing must not snap.
- Collision covers seams and perimeter; player can reach every part of the larger map with the production camera following.
- Shared material uniforms and movement history remain bounded regardless of play duration.

## Tasks

- [x] 1. Verify the existing production baseline and saved asset geometry. Record source hashes, export basis-only copies with masks/UV2, and validate the imported geometry.
- [x] 2. Write and run `tests/validate_grassland.gd` first (expect missing Grassland scene). Implement `scenes/Grassland.tscn`, terrain/scatter generation in `scripts/grassland.gd`, shared motion history in `scripts/grassland_motion.gd`, and `materials/grassland_grass.gdshader`. Test exact dimensions, reproducibility, collision, native input and no enemy nodes.
- [x] 3. Add rendered shader checks using a test-only vertex probe material, capture wind/walk/sideways/sprint/reversal/recovery, and verify planted roots, stronger sprint, distant isolation and rotated-world motion. Profile the rendered scene, run focused production regressions, and review the final change.
- [x] 4. Write `docs/GRASSLAND_E1.md` with assets, paths, counts, observations and remaining visual review. Set the review main scene and launch the normal game visibly with WASD/Shift active.

## Execution notes

Work stays in the user-requested REAL project checkout. Existing unrelated R14 Blender changes are preserved. Git commits and branch integration are outside this deliverable.

Verification: 3,031 scene/import/input checks; 308 motion checks; 21 Mobile-renderer GPU checks; ten rendered captures; 7,217 current R15 checks. Final logs are clean. Broad legacy runner: seven clean suites and thirteen baseline failures/errors, detailed in `docs/GRASSLAND_E1.md`.

Final review: independent read-only reviewer identified reversal continuity; reproduced then fixed with passing regression. Additional final checks reproduced/fixed direction cancellation and imported UV V mapping. No source geometry adjustments to grass were required. Performance evidence and artistic/device review limits are in the report.
