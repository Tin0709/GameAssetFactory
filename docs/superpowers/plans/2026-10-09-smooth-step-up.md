# Smooth step ascent

> Use subagent-driven-development for implementation and independent review; preserve file ownership. Latest user request supersedes the earlier auto-jump trial.

**Goal:** The player smoothly walks up reachable steps with existing R15 locomotion. No jumping motion or jump clips in the active game.

**Constraints:** Keep all old animation resources and Blender sources unchanged. Preserve the V2 jump study/export for later. ForestQualitySlice remains the F5 main scene; automated tests silent, manual launches normal audio. No commit/push requested.

**Implementation:** Grounded riser/top/full-capsule probes, actual travel heading, short bounded rise through the collision controller to the measured top. No ballistic impulse, apex overshoot, root teleport or additional skeleton writer. Reject tall/narrow/obstructed tops. Cancel on no input, reversal, reset/death/disable. Preserve normal freefall and grounded locomotion.

- [x] Remove active jump pose layer; restore CuboidPlayer/Visual to R15. Preserve separate Blender study and export.
- [x] Replace auto-jump physics with `smooth_step_up.gd`;100checks pass, including narrow-top analog steering and real concave forest terraces.
- [x] R15 regression7818checks and movement/weapons798checks pass. Mobile capture7checks passes; decoded9.2s MP4 frames inspected.
- [x] Independent code review addressed steering/support loss; research updated, single main worktree verified. User then requested further graphics refinement; continue that separately.

Tests use `--headless --path game_mobile_3d --audio-driver Dummy --script res://tests/validate_smooth_step_up.gd`. Review capture uses Mobile/D3D12, `tests/review_smooth_step_up.gd`, and an existing `.validation/smooth_step_up` movie output directory. Offline capture is not a phone or performance measurement.
