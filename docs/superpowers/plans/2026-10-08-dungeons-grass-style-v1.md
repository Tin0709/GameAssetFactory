# Dungeons Grass Style V1 implementation plan

> For agentic workers: use superpowers:subagent-driven-development for isolated asset authoring and review. Only additive study files; no Godot changes.

Goal: Three original Blender assets (grass_block, grass, tall_grass) inspired by the user-specified pack, prepared for visual review only.

Architecture: One dedicated new study folder contains a standalone Blender scene, independently authored low-noise pixel textures, native mobile-friendly meshes, GLB previews, a tiling showcase, renders and an asset manifest.

Tech stack: Blender 5.2.2, Python/Pillow for original procedural pixel art, glTF GLB.

Spec: The current user request supplies the complete design: resource pack as reference only, exactly three asset classes, original adjustments, cube grass block with grass top/dirt sides + grass transition/dirt bottom, small and tall lightweight grass, mobile-first, readable softer atmospheric style; no Godot integration.

Global constraints:
- Inspect only grass_block, short_grass, tall_grass and dirt texture/model dependencies within references/resource_packs/dungeons_ii_style/extracted/.
- No resource-pack bitmap, traced silhouette or UV/pixel layout is copied into authored materials; original deterministic palette/patterns and blade shapes.
- Output only blender/environment/studies/dungeons_grass_style_v1/ and scoped validation artifacts. Existing production and Blender studies remain unchanged.
- Exactly three exportable asset meshes: ENV_GrassBlock_DI_Study_V1, ENV_Grass_DI_Study_V1, ENV_TallGrass_DI_Study_V1.
- Shared original packed atlas, closest filtering; opaque cube and alpha-MASK double-sided cards; no alpha blending, physics, rigs, animations or modifiers in asset exports.
- Blender metres/Z-up, export glTF metres/Y-up, bottom-center origin, identity export transforms.
- Stop when saved Blender review setup is ready. Artistic status awaiting human review.

Review focus: cube face UV correctness; horizontal/top tiling seams; grass alpha/card readability from several angles; lightweight geometry and atlas-only GLBs; source and Godot preservation.

Task 1 — author the cohesive three-asset study
- Read .validation/dungeons_grass_style_v1/task-1-brief.md for exact contract and visual references.
- Write a reproducible authoring script only in new study folder. Author fresh low-frequency 32px textures with original muted meadow greens and warm dirt clods; reference images are read-only guides. Shared atlas no larger than 128x128 with protected gutters. Grass alpha is binary; no tinted pack pixels used.
- Cube is exactly 1x1x1m /12 triangles; small grass around0.46m high /0.58m wide; tall around0.95m high /0.72m wide. Prefer two crossed double-sided cards /4 triangles each (at most12 if a meaningful silhouette improvement needs segmented cards). Slightly original broader leaf tips/negative spaces and gentle asymmetry.
- Scene REVIEW_DungeonsGrass_Style_V1 contains three named assets with labels/scale notes, grass assets presented on linked grass-block copies, a3x3 tile area with sparse original grass/tall grass instances, neutral studio floor and warm clear lighting, and multiple cameras. Keep source assets vs presentation instances separate in collections, mark reusable native assets.
- Save dungeons_grass_style_v1.blend with packed authored textures and good material/rendered camera view. Export exactly3 isolated native GLBs into exports/; only own authored texture embedded.
- Render showcase.png, tiling.png and closeup.png with actual Blender. Create manifest.json with names, dimensions, triangle counts, material/atlas, exact reference paths/hashes, originality evidence and export hashes.
- Verify reopened blend objects, bounds, UVs, tiling edge pixels, binaryalpha, packed textures, GLB noanimations/skin/sourcepackbitmap, file paths and export base pivots. Report evidence to .validation/dungeons_grass_style_v1/task-1-report.json. No subagents; no live Blender changes.

Task 2 — independent final scoped review and presentation (root + one reviewer)
- Read author evidence and verify the saved files and rendered previews against the user requirements; consolidate necessary fixes to original author once.
- Provide review-friendly index.html/gallery in new study folder with real previews, triangle/scale notes, original-vs-reference explanation, links to blend and native GLBs.
- Open completed study in a separate visible Blender instance so existing open work remains intact; confirm review scene live. Do not modify existing Blender scenes or Godot.

Decisions: extracted/ was empty; seven matching reference PNGs were recovered from original_zip/Dungeons II Style0.2JE.zip, no unrelated contents extracted. Source pack has no models for the three assets. Complete user instructions authorize reversible study creation; stop for artistic approval after concrete results rather than adding another permission gate.

## User-approved addendum: Stone block and Dirt block

Add exactlytwo1m cubes using the same original style, and put them together with thethreeexistingassets in ONE Blender reviewscene. Allthreeblocktypes exactly1x1x1m/12triangles each. Newversiondungeons_ground_style_v2 preserves V1; retains native originalgrassgeometry/atlasregions, addsoriginalstone tofreeatlasregion, dirtusesoriginalearthtexture. Brief .validation/dungeons_grass_style_v1/blocks-addendum-brief.md; author/independentvalidation/review precede presentation. NoGodotchanges.
