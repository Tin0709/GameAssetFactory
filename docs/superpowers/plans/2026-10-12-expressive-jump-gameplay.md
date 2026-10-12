# Expressive Jump Gameplay Integration

Goal: extend the existing isolated locomotion lab with physics-event-driven Jump V2 posing. Walk/Run stay1.5x, Idle1x. Production and all Blender sources/Actions/Showcase remain unchanged; Jump V2 stays Pending.

Architecture: independent jump actor/visual subclasses reuse the current locomotion controller contract, gait clock, contact solver and R13 upper layers. A read-only native export contains the existing Pending Full Jump V2 poses, no preview trajectory. Ground preparation is compact; actual impulse starts flight, velocity/contact prediction controls airborne development, actual collision starts impact. Landing legs blend into the still-running gait before upper-body recovery finishes. Long falls settle into approach with restrained continued articulation, never repeat a fixed93-frame clip. Input remains live; buffered repeated jumps can interrupt recovery.

- [ ] Back up the current lab/docs and capture concurrency hashes.
- [ ] Add failing event/physics/pose tests; export exact source slot and validate rig, coordinates, root identity and geometry.
- [ ] Implement test-only jump subclasses, scene controls, floor prediction and event-aware phase/pose transitions.
- [ ] Validate standing/walking/running, both lead phases, repeated jumps, short/early landings, long falls, airborne direction/speed input, running recovery, upper-layer masks and30/60FPS. Keep sharp-turn limitation scoped and documented.
- [ ] Capture original-speed actual Godot three-view video, inspect pixels, document limitations and verify all protected file hashes. Leave production untouched and result Pending.
