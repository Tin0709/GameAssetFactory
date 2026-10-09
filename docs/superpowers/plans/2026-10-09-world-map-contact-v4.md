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

- [x] Add a GPU contact probe covering foot fade, wall concavity, convex edge, flat seams and vertical continuity. V3 failed the three new depth criteria; captured real-map baseline.
- [x] Add V4 shaders/preset; opaque/cutaway mismatch reproduced then corrected. Matching ground/plant root sampling retained. Switched WorldMap only.
- [x] Run GPU probe, same-camera comparison, seam and map regressions. Actual pixels inspected and RESEARCH updated; F5 ready.

Follow-up user defect: a bright hole at a sharp block tip. Two added GPU criteria reproduced missing diagonal contact. Added distance-to-footprint falloff for diagonal neighbours;15samples/14criteria pass, flat/convex cases unchanged. Six seam cases pass;7094map checks pass.18source GLBs and frozen ZIP retain hashes. No artistic or phone-performance approval claimed.

Ruling: Work in the current checkout because the user reviews this exact project with F5; preserve unrelated live Blender edits and avoid a detached review copy. No commit or deployment is requested.
