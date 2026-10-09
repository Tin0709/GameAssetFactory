# WorldMap Grounding V5 Implementation Plan

> Use superpowers:executing-plans inline. User explicitly requests fixing the supported blocks' floating appearance.

**Goal:** Replace the broad V4 contact skirt with a short strong core and weaker soft fill, preserving corner continuity and flat seams.
**Architecture:** Versioned V5 surface/ground/cutaway/plant shaders and preset; existing terrain height field and geometry unchanged.
**Spec:** User screenshot/request; current ART_DIRECTION and RESEARCH constraints.

- [x] Capture V4 same-camera baseline; reproduce missing tight-core/fast-fade criteria in GPU pixels (four failures).
- [x] Trial normal bias 0.6 separately. Keep production bias1.2 and all lighting unchanged; address contact profile only.
- [x] Add V5 profile: ground core7.5cm plus weak32cm fill; wall core7.5cm plus weak30cm fill. Preserve diagonal, concave and cutaway consistency.
- [x] Verify18GPU criteria and six floor seams; inspect actual game comparisons, preserve18GLB/frozenZIP hashes and publish F5 review. Map regression7094checks passed.

No geometry, collision, Blender, renderer, character or animation changes. V1–V4 remain available. Phone performance and artistic approval remain unverified. No delegation or commit requested.
