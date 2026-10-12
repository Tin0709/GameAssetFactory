# Directional movement refinement

Scope: existing isolated Godot test only, responsive45/90/180degree turns, support-aware rigid legs and restrained turn weight/counter-rotation. Current Jump V2/heavier landing direction is explicitly approved as the test baseline; production approval remains separate. No Blender Actions or Showcase edits.

- [x] Capture concurrent-change hashes and exact previous test/review backup.
- [x] Measure original contact drift, anchor releases, input latency, phase continuity and body/leg rotation during matched Walk/Run turns.
- [x] Target the support/swing mismatch with minimal test-only pose/contact changes. Preserve movement physics, gait clock,1.5x Walk/Run and1x Idle.
- [x] Compare original/refined at30/60renderFPS, including stops, reversals, airborne direction changes and existing jump/landing/weapon smoke regressions. Inspect original-speed actual Godot video.
- [x] Record approval scope, review status and honest residual limits; verify production/Actions/Showcase preservation. Wait for user review.

User steering incorporated:2.25x original Walk/Run pace, normal Idle, above-head straight-arm descent waves, opposing whole-leg flutter with5deg extra opening, and20% longer Run articulation paired with1.848m cadence stride. Prior stages archived. Final249turn/185fall/44stride/49landing checks pass30/60;77 original jump checks pass at1.5x/original stride. Fast2.25x stress76/77 at30,77/77at60: weapon recovery joint step remains documented. This is Pending review, never production approval.
