# Zombie short slide and collision refinement —2026-10-22

Existing ActionsStuffWalkRunTest only. Current performance actor keeps the2× launch, native mass/gravity/joints,2.5s cleanup and all50 simultaneous deaths. Ground-contact planar damping changes80→18/s; friction1 stays. First0.1s COM drift measures0.137m/60FPS and0.210m/30FPS: a brief visible slide instead of near-gluing.

Collision root cause: original corpse layer2 was included by living zombie mask7. Our mask1 alone did not remove the reverse interaction. Derived `_start_physics` now sets active corpse layer0/mask1 after native handoff. The body still collides with ground; living zombie/player/corpse movement no longer interacts with it. No production or shared death-source changes.

RED: native corpse contacts a living capsule placed in the throw path, and a real living CharacterBody test_move is blocked by the airborne chest. GREEN: both cases pass with no native contact/no swept block.23 combat checks and136 stress-lab checks pass fixed30/60FPS. Prior bullet/speed/height/range,2.5s cleanup and complete350-part release checks remain included.

Native Mobile/Metal1280×720, fixed30FPS: six-second rifle preview with a live zombie behind the killed target and three-second50-death preview. All50 show motion, remain through~2.37s then free every part. These readback captures are visual verification, not benchmarks. Original-speed clips and logs are alongside this note. Approved assets, grass, rifle/player source and WorldMap remain exact per9,049-file audit. Ready for user feel review.
