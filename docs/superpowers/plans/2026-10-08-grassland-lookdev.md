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
- Preserve wind, proximity response, anchored roots, movement history and motion masks.
- No blind SSAO/SSIL/SDFGI/glow/volumetric enabling. Use Mobile-supported, cheap alternatives.
- A/B must restore the actual original environment/materials/shadow settings without accumulating nodes or resources.
- Changing appearance or quality must not change instance counts, collision, controls or player animation.
- Scene-local resources and runtime quality changes must not leak into subsequent production scenes.
- Human art approval and Android/iOS measurements remain pending.

## Task 1: Integrated review scene

- [ ] Write a focused test proving review scene availability, A/B isolation and unchanged gameplay; run it failing before implementation.
- [ ] Create `scenes/GrasslandLookDev.tscn` and focused review-only script/material files. Provide clearly labeled current/new A/B controls and mobile/high-review options only when they improve the result.
- [ ] Render paired standing, moving, grass-detail and boundary/camera views. Inspect actual pixels and iterate on lighting/material appearance.
- [ ] Verify no errors, no enemies, movement and A/B restoration; run existing Grassland contract/motion/shader checks as relevant.
- [ ] Measure warm current/new desktop rendering and document costs, mobile tradeoffs and limitations.
- [ ] Write `docs/GRASSLAND_LOOKDEV.md` with all nine requested deliverables and exact review controls. Add a review launcher, preserving `project.godot` and previous launcher.

## Task 2: Final review and launch

- [ ] Separate read-only code review, fix material issues with focused regression evidence.
- [ ] Root inspects final rendered comparisons, checks production diff isolation and launches normal review game visibly. Do not leave a capture harness running.
- [ ] Stop with ARTISTIC STATUS: AWAITING HUMAN REVIEW. Production stays unchanged.

## Execution notes

Work in the actual project checkout so the user can immediately review it. Do not commit, stage, clean, move or revert unrelated work. The existing R14 review images are being edited independently. Tests/captures and performance logs belong in ignored `.validation` paths.
