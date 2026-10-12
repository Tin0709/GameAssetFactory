# Quicker jump gameplay review — Pending

Open `game_mobile_3d/scenes/dev/ExpressiveLocomotionTest.tscn` in Godot and press **F6**. **Space** jumps; **J** compares Previous / Quicker timing on the next launch. WASD/arrows move, Shift runs, T compares locomotion speeds (default2.25x; accepted1.5x also available). Idle stays1x. Production F5/WorldMap is unchanged.

## Original-speed review

- [Before / after comparison](comparison_1x.mp4)
- [Previous jump timing](before_1x.mp4)
- [Quicker jump timing](after_1x.mp4)
- [Matched pose samples](poses.jpg)

Actual Godot Mobile/D3D12 capture,30FPS,373 frames/12.433s per movie; no playback retiming. Stationary, walking and running jumps use matching inputs/cameras. Both comparison recordings include the continuity fix below so the comparison isolates flight timing. The complete earlier runtime checkpoint is preserved separately.

## What changed

The isolated directional test sets a1.18 flight-speed factor. Gravity scales by its square (18→25.0632m/s²) and launch velocity scales accordingly, keeping the1.2m height. Measured airtime changes0.717–0.733s→0.617–0.633s, about12–16% shorter depending on collision/tick alignment; stationary jumps are14% shorter. Measured apex remains1.19875–1.20028m.

Soft0.20s preparation and heavier0.85s impact/recovery remain. The expressive airborne arms still develop, and physics contact selects landing. The factor is latched at launch; changing J in midair affects the next jump. Unprepared ledge falls retain normal gravity. No Blender Action or animation trajectory was retimed.

Quicker flight exposed a30FPS running leg pop at LAND→GROUND: an already blended live gait was unnecessarily re-inertialized. The handoff now preserves its gait/support cache; the quieter Run body target fades in through the final0.20s recovery. Input remains immediate and the earlier impact compression remains intact.

## Validation and limits

All1516 checks across12 suites pass at30/60renderFPS with60Hz physics: quicker/original jumps at both locomotion paces, baseline jump states, matched turns, weapon interruptions and falling gestures. The strict60° joint-step guard remains unchanged (worst56.01° at30FPS,33.48° at60FPS). See the JSON evidence alongside this README.

Existing sharp-turn anchor-release sliding, rigid sole-corner rocking, terrain/full-combat coverage and actual phone performance remain limitations. This is Pending artistic gameplay review, not production approval.

Pre-change test files/docs and SHA256 baseline are in `.validation/expressive_jump_quicker_v1/before/` and `baseline.json`. All approved Blender Actions, Animation Showcase, earlier reviews, production player/WorldMap/weapon scripts remain unchanged. No new character Action was created; no Showcase registration is needed. Stop here for user review before Combat Strafe.
