# Snappier, slightly higher jump — Pending gameplay review

Run `game_mobile_3d/scenes/dev/ExpressiveLocomotionTest.tscn` with **F6**. Space jumps, WASD/arrows move, Shift runs. The window now defaults to the wider gameplay camera. **C** toggles gameplay/detail framing; **1/2/3** select close front/three-quarter/side review angles. Production F5 remains unchanged.

**J** cycles the next launch between:

| Version | Flight factor | Height |
|---|---:|---:|
| Snappier + higher (default) |1.4|1.35m|
| Previous Quicker V1 |1.18|1.2m|
| Original |1.0|1.2m|

T retains1/1.5/2.25x locomotion comparison; default Walk/Run2.25x candidate, Idle1x.

## Review

- [Original-speed before/after](comparison_1x.mp4)
- [Previous quicker jump](before_1x.mp4)
- [Snappier + higher](after_1x.mp4)
- [Matched pose samples](poses.jpg)

Actual Godot Mobile/D3D12,30FPS,373 frames/12.433s each, no retiming. Both recordings use the new matching gameplay camera and inputs for stationary/walking/running jumps. Prior close-view recordings remain preserved.

## Result and checks

The capsule reaches about1.35m (15cm higher), yet flight lasts0.550–0.567s versus0.617–0.633s for Quicker V1: roughly8–11% sooner. Gravity and launch impulse scale together; Godot collision selects contact. Soft0.20s preparation and heavier0.85s impact/recovery remain. Arms still reach the expressive airborne section, and live movement/weapon blending are preserved. Unprepared falls keep normal gravity; comparisons take effect on the next launch.

The camera uses WorldMap's orthographic12.5, slightly closer than WorldMap14.5 size,12/15/16 offset and rotation, with ground-height anchoring during flight. Test lighting/floor remain local. Camera changes do not change gameplay.

All1530 checks pass across12 suites at30/60renderFPS,60Hz physics: both locomotion paces, jump physics/height/air silhouette, J comparisons, gameplay framing, moving/repeated/early/long-fall states, matched turns, weapon interruptions and falling gestures. The strict60° joint-step guard is unchanged. The previous gait-progress test compared wrapped endpoints and falsely failed when a shorter flight completed nearly a whole gait cycle; it now accumulates signed per-sample phase increments. No runtime gait was altered to accommodate that test.

Known sharp-turn contact release sliding, rigid sole-corner rocking, general terrain/combat coverage and actual phone performance still need further validation. Pending user review; no production promotion.

Before-state files and SHA256 baseline are in `.validation/expressive_jump_quicker_v2/`. Original Blender Actions, Showcase, production and earlier reviews remain unchanged. No new Action was authored. Stop for review before Combat Strafe.
