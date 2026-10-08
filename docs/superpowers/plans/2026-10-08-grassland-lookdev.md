# Grassland look-dev review plan

> **For agentic workers:** Use superpowers:subagent-driven-development for the requested GPT-6.1 Sol High implementation and a separate final review.

**Goal:** Make the existing grassland visually warmer, richer and more readable in a review scene, with current/new A/B and a mobile-conscious quality option.

**Architecture:** Inherit or instance the existing Grassland scene and isolate all new Environment, lighting and material resources to the review. Preserve source geometry, production player, terrain, collision, seeded distribution, controls and the existing wind/interaction vertex computation. Improve the look through directional lighting, balanced ambient fill, two-sided grass shading, controlled color variation, cheap local grounding and restrained depth tint.

**Tech stack:** Godot 4.7.2 Mobile renderer, GDScript, spatial shaders. Requested worker model: GPT-6.1 Sol, High reasoning.

**Spec:** User request in `C:/Users/ADMIN/.codex/attachments/9fdeb421-6e18-406b-89f5-66c348e9310b/Pasted text.txt`; visual reference `C:/Users/ADMIN/Downloads/ChatGPT Image Oct 8, 2026, 06_56_05 AM.png`.

## Constraints and review focus

- Create a separate review/look-dev scene first. Do not modify production defaults or approved Blender sources.
- Keep 40 × 40 terrain and production player/controller/camera. No enemies or gameplay/combat redesign.
- Warm directional sun and cool fill; readable greens and player silhouette; soft grounded shadows; subtle atmosphere.
- Preserve anchored roots, movement history, continuous recovery and motion masks. Following the user's live feedback, deepen both block-top and blade greens, strengthen wind and increase player-driven splay in the new review appearance only. Current A/B keeps the approved motion unchanged.
- No blind SSAO/SSIL/SDFGI/glow/volumetric enabling. Use Mobile-supported, cheap alternatives.
- A/B must restore the actual original environment/materials/shadow settings without accumulating nodes or resources.
- Changing appearance or quality must not change instance counts, collision, controls or player animation.
- Scene-local resources and runtime quality changes must not leak into subsequent production scenes.
- Human art approval and Android/iOS measurements remain pending.

## Task 1: Integrated review scene

- [x] Write a focused test proving review scene availability, A/B isolation and unchanged gameplay; run it failing before implementation.
- [x] Create `scenes/GrasslandLookDev.tscn` and focused review-only script/material files. Provide clearly labeled current/new A/B controls and mobile/high-review options only when they improve the result.
- [x] Render paired standing, moving, grass-detail and boundary/camera views. Inspect actual pixels and iterate on lighting/material appearance.
- [x] Apply the user's darker reference palette and stronger wind/player splay feedback, with review-only shader controls and anchored-root verification.
- [x] Verify no errors, no enemies, movement and A/B restoration; run existing Grassland contract/motion/shader checks as relevant.
- [x] Measure warm current/new desktop rendering and document costs, mobile tradeoffs and limitations.
- [x] Write `docs/GRASSLAND_LOOKDEV.md` with all nine requested deliverables and exact review controls. Add a review launcher, preserving `project.godot` and previous launcher.

## Task 2: Final review and launch

- [x] Separate read-only code review, fix material issues with focused regression evidence.
- [x] Root inspects final rendered comparisons, checks production diff isolation and launches normal review game visibly. Do not leave a capture harness running.
- [x] Stop with ARTISTIC STATUS: AWAITING HUMAN REVIEW. Production stays unchanged.

## Execution notes

Work in the actual project checkout so the user can immediately review it. Do not commit, stage, clean, move or revert unrelated work. The existing R14 review images are being edited independently. Tests/captures and performance logs belong in ignored `.validation` paths.

## Follow-up: square-ended grass from Blender

**Spec:** The user's follow-up of 2026-10-08 requests broad square-ended grass rather than pointed needles, redesigned in Blender, closer grass/block colors and lighting to `C:/Users/ADMIN/AppData/Local/Temp/codex-clipboard-51777deb-1938-413c-b0b4-490be998ab9d.png`, no grass shadows, and application in the real game. Stronger wind/player splay from the previous feedback remains required.

**Live refinements:** User clarified the green cap layer on the dirt block should become exactly 15% thicker, with overall block height still 1m; this does not mean denser foliage. Additional style/light reference: `C:/Users/ADMIN/AppData/Local/Temp/codex-clipboard-55342a4d-666d-441f-8b71-bedf5f735dbb.png`. Preserve the image's warm earth, natural meadow greens, cooler blue-green shade and soft dimensional lighting, within the current map pass.

**Dirt extension:** User also requests a separate warm ochre pixel-textured bare dirt block, based on `C:/Users/ADMIN/AppData/Local/Temp/codex-clipboard-2a98967b-27dd-4356-8a19-707fc285c8db.png`. Add the editable Blender object and `dirt_block_v4.glb` (1m cube, no grass cap). For actual lighting review, only LookDev shows an optional centered 4×2 strip of 8 dirt cells within the cleared spawn area, using the imported mesh and atlas. Main grassland remains all grass blocks, collision/layout/scattering stay intact, and Previous v3 restores all-grass terrain. F4 toggles the sample if unused by existing controls.

**Direct asset review:** User requested Blender visibly open. It was launched with the saved v4 study; retain that window for the user while game integration continues. Do not overwrite user edits or close their Blender session.

**Weather refinement — deferred:** The user subsequently requests completely removing fog for now and experimenting later. Remove fog timing, runtime controls and active effect from both v4 and Previous comparison. Preserve the shared original environment resource; Previous uses a scene-local copy with fog disabled and its other settings restored. Keep fog experiment evidence separate from the active game, and document that it is deferred.

**Ruling:** Treat application to the game as authorization to adopt the new asset/presentation in the grassland scene, while preserving archived v3 files and original look for comparison. Keep player, combat and terrain layout intact. Continue in this existing checkout for direct review; no stage/commit or worktree changes. No grass cast shadows or fake grass grounding blobs in either quality mode. Player shadows remain.

### Task 3: Authored Blender v4 asset

- [x] Write and run a focused failing asset validation before creation.
- [x] Build `blender/environment/studies/grass_block_reference_v4/grass_block_reference_v4.blend` with flat rectangular square-ended blades, varied width/height/angles, opaque pixel materials, four bend rings, exact anchored roots and UV2 data. Prefer 32–40 broad blades, roughly .28–.48 m tall and .12–.20 m wide; judge final silhouette against the reference.
- [x] Create reference-informed meadow/dirt atlas; preserve v3 source and exports. Save an editable Blender scene, wind preview and asset metadata.
- [x] Export `game_mobile_3d/assets/environment/grassland/grass_patch_v4.glb`, `grass_dirt_block_v4.glb`, `environment_atlas_v4.png` and `export_manifest_v4.json`. Keep block dimensions exactly 1m and root mapping compatible with the existing shader. Validate geometry, masks, source preservation and mobile triangle budget.
- [x] Add and validate the bare dirt block, its original atlas tiles and real paired Blender preview.

### Task 4: Real-game presentation and integration

- [x] Write a focused regression proving the v4 asset is used, square ends survive import, roots/masks retain movement support, and grass never casts shadows, including F3/current-new switches. No fake grass shadow map.
- [x] Apply v4 assets and reference-like grass/ground colors, warm key/cool fill and player shadow improvements in the real grassland runtime. Preserve controls/combat/no-enemy review guard and 40×40 layout. Fog is deferred by the latest user instruction.
- [x] Keep useful previous/new comparison, without using numeric weapon keys or enabling grass shadows. Retain stronger wind and player splay safely for shorter blades.
- [x] Import assets, run motion/scene/GPU checks, capture gameplay/detail/wind/movement/boundary and inspect actual pixels. Tune shape/color/light before final comparison.
- [x] Record warm rendering measurements and their historical limits, update documentation, obtain separate read-only review, and open the actual updated game for human review.
- [x] Remove active fog according to the user's latest instruction, verify both appearances remain fog-free, archive experiment evidence and obtain a scoped re-review before final launch.

**Worker interfaces:** Task 3 owns Blender scripts/study and v4 assets only. Task 4 owns Godot scripts/materials/tests/scenes/report only, consumes those exact v4 paths, and may prepare integration while export is underway. Rendering/import/testing are serialized after the assets arrive. Requested worker model remains GPT-6.1 Sol High.

**Final evidence:** Both Blender asset validators pass; seven protected v3/player/combat files retain their hashes. Fresh runtime checks pass (929 v4/no-fog, 1927 soil, 434 review and 434 combat-flag review), with 11 new and 21 preserved GPU shader checks. Root reran the final 929-check contract and inspected the refreshed standing/detail/soil pixels. There are 31 active no-fog captures, with prior/fog images archived separately. Independent read-only review reports no remaining findings. The saved Blender study remains open for direct review, and the normal LookDev game was launched visibly on Mobile/D3D12 (PID 18032), with a clean startup log. ARTISTIC STATUS: AWAITING HUMAN REVIEW.
