# Smooth step ascent

> Use subagent-driven-development for implementation and independent review; preserve file ownership. Latest user request supersedes the earlier auto-jump trial.

**Goal:** The player smoothly walks up reachable steps with existing R15 locomotion. No jumping motion or jump clips in the active game.

**Constraints:** Keep all old animation resources and Blender sources unchanged. Preserve the V2 jump study/export for later. ForestQualitySlice remains the F5 main scene; automated tests silent, manual launches normal audio. No commit/push requested.

**Implementation:** Grounded riser/top/full-capsule probes, actual travel heading, short bounded rise through the collision controller to the measured top. No ballistic impulse, apex overshoot, root teleport or additional skeleton writer. Reject tall/narrow/obstructed tops. Cancel on no input, reversal, reset/death/disable. Preserve normal freefall and grounded locomotion.

- [x] Remove active jump pose layer; restore CuboidPlayer/Visual to R15. Preserve separate Blender study and export.
- [ ] Replace auto-jump physics with `smooth_step_up.gd`; test real capsule on .5m/1m walk/sprint/diagonal, flat, walls, low ceilings, narrow tops, cancellation and real forest terrain.
- [ ] Run existing movement/weapon regression and capture actual Mobile-rendered ascent/descent with old clips; inspect encoded frames.
- [ ] Independent code review, concise research/constraints update, Git/worktree check and handoff.

Tests use `--headless --path game_mobile_3d --audio-driver Dummy --script res://tests/validate_smooth_step_up.gd`. Review capture uses Mobile/D3D12, `tests/review_smooth_step_up.gd`, and an existing `.validation/smooth_step_up` movie output directory. Offline capture is not a phone or performance measurement.
