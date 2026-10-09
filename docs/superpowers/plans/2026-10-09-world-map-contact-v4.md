# WorldMap Contact V4 Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for this authorized inline task. No delegation.

**Goal:** Strengthen soft terrace foot contact and concave wall corners without outlining flat block seams.

**Architecture:** A versioned V4 surface include and matching ground/cutaway/grass shaders share the existing height field. Reuse V3 lighting, vegetation animation and source geometry; switch only WorldMap's preset.

**Tech Stack:** Godot Mobile 4.7, spatial shaders, GPU SubViewport review.

**Spec:** User-approved in-chat analysis and subsequent instruction to apply it; `docs/graphics/ART_DIRECTION.md` and `RESEARCH.md` remain binding.

## Constraints and review focus

- Keep Blender, source GLBs, terrain placement/collisions, all animation, V1–V3 and frozen ZIP unchanged.
- Preserve exposure .96, warmth .05, current sun/fill/haze and grass blending.
- Shade only actual taller neighbours and concave contacts; no convex/flat grid outlines.
- Opaque and cutaway shading must agree; retain walkable ground opacity.
- Desktop GPU checks do not establish phone 30 FPS or artistic approval.

## Execution

- [ ] Add a GPU contact probe covering foot fade, wall concavity, convex edge, flat seams and vertical continuity. Observe expected V3 failures; capture reproducible real-map baseline.
- [ ] Add V4 shaders/preset, strengthen bounded contact falloff and wall concavity from actual height neighbours; keep grass-root sampling consistent. Switch WorldMap only.
- [ ] Run GPU probe, same-camera comparison, existing seam and map regressions. Inspect actual pixels, update RESEARCH and make F5 review ready.

Ruling: Work in the current checkout because the user reviews this exact project with F5; preserve unrelated live Blender edits and avoid a detached review copy. No commit or deployment is requested.
