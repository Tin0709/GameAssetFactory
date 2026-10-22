# Combat feel refinement — current dev lab, 2026-10-22

Existing `res://scenes/dev/ActionsStuffWalkRunTest.tscn` only. Default20, exact0–50 spawn controls, simultaneous Kill All and approved player controls remain. No scene/project/Action candidate is added.

## Current experiment

- Vegetation is temporarily hidden and its frame/physics work paused through `grass_vegetation_enabled=false`. All1,317 clumps,32 batches, meshes, shaders, atlases and contact/wind improvements are retained; the900-block30×30 terrain stays visible. Set this flag true to restore grass on the next launch.
- Bullets use the animated muzzle origin and its planar forward direction, discarding vertical pitch. This removes intermittent downward shots while preserving all approved rifle/arm animation. The existing fixed16-bullet pool, swept rays, damage and6Hz cadence remain. Speed20→30m/s; range15→45m. Invisible arena walls are a separate static body excluded only from these dev rifle rays; the real floor and zombie collisions remain. Flash orientation follows the same flight direction. Existing aim alignment and point-blank grip-to-muzzle checks remain.
- The performance zombie subclass doubles the original combat impulse once:240→480N·s directional,48→96N·s upward. With unchanged60kg mass, this doubles impulse-derived launch speed; no extra velocity/time multiplier is stacked. Gravity18m/s², seven bodies/six joints, CCD, angular impulse, handoff, source clips and numerical speed guards remain.
- Corpse lifetime1.2→2.5s. Surface friction rises.75→1.0. Actual Hips/Chest/Head floor contacts engage exponential planar velocity arrest for the whole graph (`exp(-80*dt)`), leaving vertical and angular physics native. Initial planted feet cannot prematurely cancel the throw. A corpse propped on limbs may settle through normal friction without the core contact latch. All50 can still run together; duplicate lethal hits cannot relaunch them.

The contact callback uses native direct-body state ([Godot API](https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate3d.html)); the current flatY0 floor is an explicit dev assumption. These values are an original gameplay tuning experiment, not a claim about MD2 implementation.

## Fresh verification

21 actual-scene checks and136 performance-lab checks pass at fixed30/60FPS. Tests exercise a pitched animated barrel,30m travel in1s, constant shot height, passing the invisible boundary,45m expiry, fast swept damage against a real zombie, native doubled impact, post-impact arrest, duplicate damage and full teardown. Measured first0.1s of post-contact COM drift:0.054m at30FPS,0.071m at60FPS; the airborne COM first reaches about9.7m/s including inherited movement. Corpses persist beyond the old1.2s and release at2.5s. Both rifle30/60 regressions preserve grips/support, lower-body animation, camera and120-shot continuous fire without pool misses. Legacy four-actor combat retains original1.2s and physics.

Native Mobile/Metal, AppleM2Pro,1280×720: [six-second held-E combat](rifle_combat.mp4), [three-second simultaneous50 death](kill_all_50.mp4), both30FPS at original speed. Rifle kills the real target with5 shots/no pool misses; landing follows13 frames after death. Mass test records50 moving chests/350 native parts, all50 retained through frame70 (~2.37s), one lethal event each, then all native parts released. No startup/renderer/script errors. Readback capture is not an FPS benchmark or phone performance claim. Native frame sequences were inspected alongside pose/position samples.

Protected-file SHA audit is included in `preservation.json`: approved Blender/source assets, grass source and production WorldMap unchanged. Earlier performance samples and1.2s reports are historical. Current implementation awaits the user's feel test.
