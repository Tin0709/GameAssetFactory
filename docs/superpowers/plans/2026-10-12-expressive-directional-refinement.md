# Directional movement refinement

Scope: existing isolated Godot test only, responsive45/90/180degree turns, support-aware rigid legs and restrained turn weight/counter-rotation. Current Jump V2/heavier landing direction is explicitly approved as the test baseline; production approval remains separate. No Blender Actions or Showcase edits.

- [ ] Capture concurrent-change hashes and exact previous test/review backup.
- [ ] Measure original contact drift, anchor releases, input latency, phase continuity and body/leg rotation during matched Walk/Run turns.
- [ ] Target the support/swing mismatch with minimal test-only pose/contact changes. Preserve movement physics, gait clock,1.5x Walk/Run and1x Idle.
- [ ] Compare original/refined at30/60renderFPS, including stops, reversals, airborne direction changes and existing jump/landing/weapon smoke regressions. Inspect original-speed actual Godot video.
- [ ] Record approval scope, review status and honest residual limits; verify production/Actions/Showcase preservation. Wait for user review.
