# R4-G isolated locomotion lab plan

Goal: export the six existing V2 study actions and provide a playable artistic-review lab, without production changes.

Spec: user’s PHASE R4-G request. Execute directly in this workspace; all deliverables are separate test files.

1. Export copies from the turning V2 study in background Blender. Validate six durations, source matrices, seams, static Root, scale exclusion, geometry and source preservation before importing into Godot.
2. Create `scenes/dev/LocomotionTurningLab.tscn` and local scripts. A CharacterBody moves in world XZ; its visual faces smoothly. Sample the imported AnimationPlayer library at one normalized phase; interpolate absolute positions and quaternions. A/B changes only turn weight. Walk/Sprint blend over 0.14 seconds while preserving phase; authored cadence is 1.0.
3. Verify actual movement, equivalent A/B trajectories, signed circles at all headings, wraparound, opposite-turn recovery, native source poses and gait transitions. Render normal-speed straight/mild/tight examples and measure sole movement separately from pose banking. Document limitations; leave the lab open in manual mode.

Review focus: +Z character forward means local left is +X; positive world-Y yaw is left. No camera-derived turn sign. Shift at arbitrary phases must preserve phase. Facing crosses ±PI without jumps. A/B must not alter clocks/steering. Releasing input freezes gait phase; no new start/stop action.
