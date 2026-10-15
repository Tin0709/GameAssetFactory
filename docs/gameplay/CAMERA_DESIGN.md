# Comfortable gameplay camera

Permanent user direction, 2026-10-15; inspired by Minecraft Dungeons' stable, readable framing. This specifies our implementation philosophy, not a claim about that game's internal camera algorithm.

Follow horizontal X/Z travel smoothly. Keep camera height independent of normal jump height so the player rises and falls inside a stable frame. Never add incidental locomotion bob, shake or a vertical lock to the jumping capsule. Preserve the established angle, distance, framing and mobile readability. Slopes, platform changes and long falls should adjust height with damping while keeping the player visible; takeoff and landing must not reset camera position or velocity.

## Current research implementation

Only `game_mobile_3d/scenes/dev/ActionsStuffWalkRunTest.tscn`, via its existing `actions_stuff_research/walk_run_test.gd`, is changed. The anchor follows X/Z exponentially at12/s. A1.4m upward/1.1m downward airborne dead zone keeps the existing1.26–1.31m ordinary physics jump completely inside a fixed vertical frame. Outside that zone, an exact critically damped8/s spring adjusts elevation; quarter-second vertical velocity anticipation activates only outside the zone to follow long falls. Grounded height changes use the same spring. The camera's position and velocity remain continuous at takeoff/landing. Explicit R teleport rebases the camera immediately.

Original orthographic size5.1,8m distance, azimuth.66/elevation.40, orbit/zoom and aim offset.95m are retained. Movement, gravity, jump height, controls and animation data are unchanged by the camera adapter.

## Verification and future integration

`test_camera_comfort.gd` checks30/60Hz, horizontal tracking, zero normal-jump camera-height change, smooth large elevation changes/long-fall zone recovery, grounded settling and original framing. Native Metal rendering checks full character/feet visibility during the actual standing/moving jump. Flat-ground research cannot certify arbitrary production terrain or every mobile aspect ratio; test the same philosophy against actual level slopes/falls and target screens when main integration is authorized.

Apply this rule to future authorized main-game integrations. Do not change WorldMap or production camera until explicitly requested. No new scene or project is required.
