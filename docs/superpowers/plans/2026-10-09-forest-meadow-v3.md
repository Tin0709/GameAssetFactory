# Forest meadow V3 refinement

Latest user request: after completing smooth step ascent, substantially improve the game graphics against the two supplied comparison images. Smooth ascent is complete; jump animation remains deferred.

**Observed gap:** V2 has horizontal comb-like tree crowns, repetitive tall grass patches, flat material values and limited cliff/ground layering. The supplied gameplay reference has chunky leaf masses with fine irregular leaf patterns, pale grass tips, broken grass/soil borders and strong green/earth/cool-stone separation. These are image observations; no inference of the reference game's renderer is treated as fact.

**Design:** preserve V2 source/scene for comparison. Build V3 as a scene-local extension of ForestQualitySlice. Keep character/camera/old animations, broad-grass v4 deformation contract, no fog or grass shadows, and the same controller/combat. New reusable original V3 vegetation; materials and distribution improvements; stronger terrain backdrop with reachable .5m terraces around the lane. Use bounded PCF sunlight/ambient adjustments after checking geometry under existing light. No engine/global rendering architecture change.

1. Save user references and capture actual V2 baseline with matched pose/camera.
2. Create/validate reusable canopy V3 sources and GLBs (asset agent owns only V3 asset folders).
3. Parent builds V3 scene/script/materials, preserving V2; iterate actual Godot captures. Secondary read-only reference/review agent checks image inference and implementation.
4. Verify terrain/collision/smooth-step and old animation invariants, inspect actual gameplay video, measure desktop render cost separately. Phone30FPS remains unverified until a minimum phone is available.
5. Update graphics research/art-direction/asset reuse links with verified methods, proposals and remaining gaps; final Git/worktree check. F5 opens latest gameplay study with normal audio; automated tests silent.

No style is marked approved without explicit confirmation. No commit/push requested.
