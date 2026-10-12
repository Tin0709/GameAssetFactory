# Heavier gameplay landing — Pending

Open the same `game_mobile_3d/scenes/dev/ExpressiveLocomotionTest.tscn` and press **F6**. Space jumps, WASD moves, Shift runs. **B switches Heavier / Original landing**; the HUD names the current option. Heavier is the new default. Walk/Run remain 1.5× and Idle 1×. Production F5/WorldMap is unchanged.

[Updated original-speed gameplay](gameplay_1x.mp4) · [Synchronized Original vs Heavier comparison](comparison_1x.mp4) · [Impact poses](impact_comparison.jpg). Both videos contain 504 frames at 30 FPS, 16.8 seconds, recorded from actual Godot Mobile/D3D12, with front/three-quarter/side views and no temporal retiming. The earlier [original review](../godot_jump_v1/gameplay_1x.mp4) remains unchanged.

## What changed

The existing physics/event-based jump is preserved. This is a small **runtime-only contact pose accent**, not a revised Blender Action. Extra hip drop is 20 mm stationary, increasing to 40 mm at full Run; added rigid chest pitch is 1.5°–3°. The running amount is latched on contact so a speed change during absorption does not abruptly change the load. The accent eases in over 100 ms, stays fully loaded through 160 ms, then eases out by 400 ms. The original controlled rebound remains.

The stronger running dip reads as momentum absorption while the moving legs continue their existing gait release over 80–320 ms. Horizontal speed, acceleration, air control, jump height, launch/landing events, source phase timing, repeated-jump buffer and gait phase are unchanged. No movement lock, added landing delay, extra airborne elevation, scale deformation, invented joint or second bounce. Existing weapon layering still applies above the base pose.

Disabling the accent with B restores the previous landing target exactly; switching marks the pose for the existing continuity treatment. For automated/original playback, launch with `-- --expressive-landing-original`. Exact previous scripts/scenes/docs/video hashes and copies are preserved under `.validation/expressive_jump_heavier_landing_v1/before/`.

## Checks and evaluation

At matched 30 FPS conditions, measured extra hip dip is **19.7 mm stationary / 39.6 mm running**. Physical peak, flight timing and final running speed match the original comparison. The running impact is visibly lower with a slightly stronger torso reaction, while the arms retain their independent expressive articulation. The release remains quick enough for continued Run and buffered repeat jumps.

**49 matched comparison checks and 77 full jump checks pass at both 30 and 60 render FPS**, with 60 Hz physics. Tests cover planted clearance, uninterrupted Run speed/shared phase, stationary/moving/repeated/short/platform/ledge/long-fall cases and existing weapon mask/socket smoke checks. See [comparison 30](comparison30.json), [comparison 60](comparison60.json), [jump 30](runtime30.json), [jump 60](runtime60.json).

Across the stress suite, grounded sole penetration remains below 0.001 mm. Bounded-anchor residual still reaches approximately **7.8 cm at 30 FPS / 7.5 cm at 60 FPS** during difficult moving contacts. The earlier sharp-turn sliding limitation remains; this refinement does not redesign directional locomotion or certify uneven terrain. Rigid boots still rock on corners, and abrupt repeat/short-flight gestures remain fast. Mobile performance and full combat validation remain outstanding.

Jump V2 and this gameplay refinement remain **Pending user review**. Approved/source Actions, the Animation Showcase, native jump library, previous reviews, production controllers, weapons, project settings and WorldMap remain unchanged. Only this test's pose/UI/measurement code and Pending documentation metadata change. [Preservation audit](preservation_validation.json).
