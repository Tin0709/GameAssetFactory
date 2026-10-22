#1.2×pace and wider camera —2026-10-22

User authorizes20%faster travel and animation, plus a wider MD2-like view using the supplied gameplay screenshot. SAME `ActionsStuffWalkRunTest.tscn`; no new scene/project or approved Action change.

Scene values: movement multiplier1.2, locomotion playback1.2, camera size14.5. Walk2.16m/s, Run6.0372m/s, gait1.50/1.92cycles/s. Physical distance per cycle remains1.44/3.144375m; playback is not multiplied twice. Scale planar acceleration/deceleration to48/42m/s² with travel, keeping start/stop times and normalized direction changes like the previous1×baseline. Turning spring/QC/E timers and jump gravity/height are unchanged; no global timescale change, fire cadence remains6Hz.

Orthographic framing7.2→14.5, original azimuth0.66/elevation0.40 preserved. Camera distance scales above the old framing (normal distance20.1389m) so the wider near plane remains above the floor. Wheel limits3.6–24, step0.3; no jump back to the old8mceiling. Voverview43/follow/jump dead zone remain unchanged. This is an authored match to the reference framing, not verified MD2 engine settings.

At1280×720 native Mobile, vertical1.8mactor measure occupies11.43%of frame versus23.03%before; actual hair/body render inspected. Default near-bottom rayY2.095m stays above the ground. [Before](before.png) · [After](after.png) · [4.5soriginal-speed gameplay clip](gameplay_1_2x.mp4), showing Walk→Run→releaseShift and a jump. Capture-only fixture omits zombies/UI for readability; saved gameplay retains20zombies and existing controls. Readback is not a performance benchmark.

Necessary internal checks: exact speeds/cadence/stride and12prior motion checks at30/60FPS; stopped gait has no tail, Shift release returnsWalk, tiny taps stay planted, circle lag matches the prior1×baseline after scaling response. Camera comfort30/60shows zero vertical normal-jump travel;159-shotFire30check preserves both grips/recoil recovery/pool behavior. All logs are alongside this guide. Approved Blender files/Actions, rifle source assets, terrain/grass/zombie systems and WorldMap are unchanged; see preservation.json. Ready for user gameplay review.
