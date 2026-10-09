# Gameplay map border implementation plan

> **For agentic workers:** Use superpowers:executing-plans inline. No delegation or integration commit is required for this local review.

**Goal:** Keep the playable grass floor 100 × 100 metres and surround it with uneven grass-capped dirt and stone cliffs at least 10 blocks above the floor.

**Architecture:** A scene-local height field creates broad, coherent voxel masses outside the existing floor. Emit only exposed unit-block faces into chunk meshes, using the original V3 block UVs/materials and matching static collisions. Keep the existing actor, camera offset, environment and Mobile renderer.

**Tech Stack:** Godot 4.7.2, GDScript, native V3 GLBs, Mobile/D3D12 captures.

**Spec:** User's current grass and cliff images; project constraints in `AGENTS.md` and `docs/graphics/ART_DIRECTION.md`.

## Constraints and review focus

- Preserve the full 100 × 100 flat interior, block scale 1 m and existing player animations.
- Every perimeter cell and corner needs a solid border, including transitions between dirt and stone.
- Heights must vary in groups, with no uniformly spaced thin columns; all cliff columns are at least 10 m above the floor.
- Reuse block UV density rather than stretching a one-block texture over a tall column.
- Inspect actual gameplay views near all four sides for camera occlusion; keep any necessary cutaway scene-local and retain collision.
- Automated tests use process-only Dummy audio; the user's F5 run uses normal audio.

## Task 1: Quiet grass material

Files: `game_mobile_3d/materials/gameplay_grass_ground.*`, `scripts/gameplay_map.gd`.

- [x] Capture the native material baseline and adjust only the ground material.
- [x] Capture actual Godot pixels at the same camera/pose; compare the olive colour and low texture contrast with the supplied image.

## Task 2: Continuous cliffs and gameplay review

Files: new `scripts/gameplay_map_border.gd`, new `tests/validate_gameplay_border.gd`; modify `scripts/gameplay_map.gd` and `tests/review_gameplay_map.gd`.

- [x] Write and run a failing runtime test: border exists; downward rays hit heights at least 11 m at every sampled edge and corner, varying by at least 5 m; underlying floor remains Y=1.
- [x] Implement `build()` on a new border Node3D, with height/material fields outside the interior, exposed-face chunk meshes and matching colliders.
- [x] Run border and floor/controller tests; check real player movement against the wall.
- [x] Capture the full map and all four sides in Godot, inspect pixels, and resolve actor occlusion revealed by those views.
- [ ] Update the existing graphics documentation and restart F5 in the open editor for direct review.

## Execution rulings and review

User steering added lower inner columns and soft translucency during implementation. The original 100 × 100 floor stays intact beneath those columns; the floor ray tests exclude border colliders, and border tests separately assert the central free area and real raised inner surfaces.

Independent review found that the original wall test spawned inside a new buttress and could mask escape through the existing fall reset. The final test confirms a clear approach using a downward ray, tracks every movement frame and requires actual border contact. Initial red tests failed for absent outer border and then absent inner columns; final floor/border checks are 243/423 with zero failures.

The foreground uses smoothly varying alpha, with opaque shadow-only casters and unchanged collisions. A pixel-discard trial was superseded by the user's requested translucency. Shadow-bias and shader caster-inset trials were discarded: retain original sun settings and character contact shadow; flat floor stops casting its own stipple, while still receiving shadows. Some small stipple on cliff tops remains pending further visual refinement, without claiming artistic approval.
