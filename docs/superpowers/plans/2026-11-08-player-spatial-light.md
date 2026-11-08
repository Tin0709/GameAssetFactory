# Player spatial lighting implementation plan

> Execute inline with superpowers:executing-plans. User explicitly approved applying the preceding source-backed research to the existing gameplay scene; no repeated approval gate.

**Goal:** Improve dynamic player shading in the existing F5 WorldMap without changing gameplay, assets, global lighting or terrain.
**Architecture:** Original offline six-direction RGB irradiance volume from original GAF solid grid/face-average albedo. CPU trilinear sampling at three body heights; forward shader replaces only the actor ambient term. Independent rough specular approximation uses the same low-frequency incident field. Private hash-gated MRES alpha supplies a selective, energy-normalized diffuse wrap approximation; it is not native screen-space SSS.
**Tech stack:** Existing Python/Numpy terrain tracer; Godot4.7 Mobile/D3D12; GDScript and existing player shader variants.
**Spec:** MD2 Research/godot_lab/world_map_unified_showcase_v001/player_light_followup_v002/index.html and user's apply-to-main-game instruction.

## Constraints / rulings
- Work in requested existing main checkout (AGENTS main workflow); preserve pre-existing uncommitted terrain edits via private backup. No new project or scene.
- Do not alter skin/weapon/rig/animation/controller/camera/grass/terrain shaders/global sky or fog. No new software or capture.
- Source mask stays external and editor-only; bake uses original map inputs only. No proprietary data in Git/assets/builds.
- Native MD2 input/branch proof is distinct from original diffuse volume, rough specular proxy and wrap width .15. Do not claim Lumen/native SSS equivalence.
- Six-axis incoming field is coarse/low frequency; no runtime physics rays, moving occluder tracing or sharp reflection. Out-of-volume/solid/fallback restores former ambient.
- Ambient contribution replaced, never added on top. Canopy visibility remains independent. Default combined and each new comparison toggles available in L; previous exact path retained.

## Steps
- [x] Write and observe failing cache/lighting contracts. Preserve source baseline screenshots.
- [x] Bake original volume from prior terrain exporter input; validate empty-space occupancy/constant-sky normalization/colored bounce; pack compressed original Resource.
- [x] Implement validated trilinear sampling, original ambient/specular shader helper and private mask/wrap path; integrate lifecycle/guards/UI into existing WorldMap.
- [x] Run meaningful synthetic/native shader, baseline restore, lifecycle, fallback, existing player/terrain/grass/showcase tests. Inspect same-camera screenshots in sun and cliff shade.
- [x] Exercise actual movement/jump/combo at30/60/120; measure desktop Mobile cost with explicit phone limitation. Correct defects and document evidence boundary.
- [x] Update handoff, open normal existing F5 gameplay for review. Preserve all source/evidence. No automatic publish required by this request.

Final review: two cache-gate issues fixed and native39 contracts pass; read PLAYER_SPATIAL_LIGHT.md for measured limits. Existing main checkout confirmed origin/main. Pre-existing terrain edits preserved, whitespace-only mist import left untouched. No native SSS/Lumen equivalence claim.
