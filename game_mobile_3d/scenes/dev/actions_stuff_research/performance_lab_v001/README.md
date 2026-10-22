# Adjustable zombie performance lab — existing scene only

Current `res://scenes/dev/ActionsStuffWalkRunTest.tscn` opts into `performance_test_enabled=true`. It retains the 30×30 ground, player/rifle, lighting controls and approved movement. The latest combat-feel experiment temporarily hides/pauses all 1,317 grass clumps while retaining their complete source/resources for restoration. The optional lighting review blocks/trees/flowers and their colliders are omitted. WorldMap, project defaults, approved Blender files, grass shader/motion and existing AI/animation/death source files are unchanged.

## Controls

- Default: 20 living zombies, simultaneously instantiated.
- Bottom-left **Performance Test**: slider selects every integer 0–50, with 0/10/20/50 shortcuts. Selecting changes the pending count; **Spawn N** replaces the old group with exactly N new actors in one batch. It does not add to the previous group.
- **Spawn 0** immediately clears living actors and all corpses/native resources for the no-zombie baseline.
- **Kill All** applies lethal damage to every survivor immediately. Every spawned actor runs its existing native death at the same time, including all 50 ragdolls/350 physical parts. No corpse is culled or queued to hide the load. Every corpse currently retains a 2.5-second lifecycle.
- **R** resets player/fire/targets and restores the last applied batch count. Unapplied slider changes do not alter R.
- **V** keeps the existing whole-field overview; E/aim/fire, movement, jump, Q/C and camera controls are unchanged. There are no automatic waves or respawns.

## Implementation and preservation

The existing four-actor encounter gains only two narrow overridable hooks for positions/actor script. This subclass provides a deterministic, non-overlapping ring of valid positions inside the floor, excluding a 2m region around the player. All spawned actors start their existing persistent chase, with unchanged speed/melee/source clips. Spawn is event-driven, not streamed across frames. The performance actor reuses the original native-death implementation without admission limits. The latest authorized experiment doubles directional/lift impulses, extends cleanup to 2.5s and adds native floor-contact planar arrest; the original handoff, masses, gravity, joints, CCD and source clips remain unchanged. The original four-actor opt-out fixture keeps its previous death settings.

The controls clear stale auto-aim targets/projectiles before replacement, use no keyboard focus, and refresh telemetry at 4Hz. `Frame` is 1000/FPS, not GPU time. `Process`/`Physics` are Godot's CPU monitor timings. The existing lighting panel still shows render counters/quality/time. GPU timing remains N/A on this tested Metal path.

The opt-in defaults false in the shared lab script. Setting it false restores the original four-zombie fixture plus lighting review props. Legacy four-actor combat, auto-aim and hit-feedback capture fixtures explicitly opt out. No production scene is affected.

## Current combat-feel experiment

The saved lab hides grass via `grass_vegetation_enabled=false`; set true before launching to restore the complete retained wind/contact/shadow version. Performance mode levels rifle flight from the actual muzzle, increases projectile speed20→30m/s and range15→45m, and excludes only invisible arena walls from bullet rays. The shared production weapon profile is unchanged. `physics_zombie.gd` duplicates the existing combat preset and changes240→480N·s directional/48→96N·s lift once; this doubles impulse-derived speed with the same masses. `grounded_part.gd` extends the original guard and arrests XZ velocity after a Hips/Chest/Head contact with the flatY0 ground, without changing native transforms, falling or angular motion. Corpse friction is1.0; lifetime2.5s. No hidden ragdoll cap is restored. See `docs/graphics/reviews/combat_feel_v001/README.md`.

Fresh21 combat-feel and136 performance checks pass fixed30/60FPS. Both rifle30/60 regressions and legacy combat pass. Native held-E combat and all50 simultaneous deaths were recorded at original speed; all350 parts are freed after cleanup. These captures are not performance benchmarks.

## Latest refinement — brief slide, corpses pass through zombies

The user requests a little slide rather than near-instant adhesion. Current planar damping is18/s (previous80/s), with friction1.0 retained. Actual floor contact still begins the damping, leaving the airborne launch unchanged. In the real-scene test, COM travels0.14–0.21m during the first0.1s after contact and settles quickly.

Original corpse parts advertised layer2, which living zombie mask7 includes. Although the corpse mask1 ignored living actors, the reverse collision still blocked/pushed them. The performance subclass now sets running corpse parts to layer0/mask1 after the original native handoff. This keeps ground collision and makes interaction with living zombies, player and other corpses absent in both directions. Original shared death source/production files remain exact.

23 actual-scene checks pass fixed30/60FPS, including native corpse contact recording with a living zombie directly in the launch path and an actual living CharacterBody sweep across the airborne chest. Both tests reproduced unwanted collisions before the fix and now pass. Existing136 performance checks also pass at both frame rates, retaining all50 simultaneous corpses/350 parts and2.5s cleanup. Bullet tuning and approved animation/control behavior are unchanged. Current evidence: `docs/graphics/reviews/zombie_slide_pass_v001/`.

## Historical verification before combat-feel tuning

135 actual-scene checks passed at fixed30/60 FPS: exact counts including 0/1/13/20/50, bounds/clamping/separation, repeated Spawn, corner R reset, button signals, immediate/double Kill All, all-50/350-part simultaneous death and retention, 1.2s cleanup and native resource teardown. Existing four-actor damage/handoff and auto-aim regressions pass, as do 20 lighting checks. Fresh native held-E gameplay kills a performance actor with the existing rifle (11 shots, 133 frames, no pool misses). Read-only final review found one minor reset-order edge, reproduced and corrected before these final checks.

Historical living-only samples before the full-death change: Native Mobile/Metal, Apple M2 Pro, 1280×720, Medium, fixed V overview, capped60, 120 samples per count, after a warm-up. No other gameplay instance was running. Measured wall-frame medians were about 16.6–16.7ms and p95 17.6/17.9/18.2ms for 0/20/50. Recorded CPU physics p95 was 5.21/6.73/9.69ms. Spawn setup itself measured 3.0/6.1/17.6ms. These are desktop observations from the manual-draw sampling helper, not phone benchmarks or guarantees of an isolated GPU budget. Capture readbacks occur outside sample windows.

Evidence: `docs/graphics/reviews/zombie_performance_lab_v001/` at repository root, including native images, raw samples and validation summary. The original three-second post-benchmark firing observation did not kill a target; the fresh extended firing check verifies lethal damage separately, without changing combat behavior. This lab is ready for the user's performance experiments, not an artistic approval or release promotion.

## Latest user correction — full simultaneous death load

The four-ragdoll retirement policy is removed from performance mode. It had made all but the latest four victims disappear immediately, defeating the user's full-load experiment. Kill All now applies all lethal events in one call; warmed actors all start native physics immediately, while a just-spawned unwarmed batch all starts together at the next existing physics step. Repeated Kill All cannot trigger duplicate handoffs. Both the performance panel and original HUD show active ragdolls against the actual applied batch size. The original four-zombie opt-out fixture is unchanged.

New native proof: 50 initial ragdolls, 350 physical parts, measurable motion in all 50 chests, one death trigger each, all 50 retained at capture frames2/14/26 of fixed30FPS playback, and every native part freed after the original lifetime. A 45-frame/1.5s native clip at original speed and the result/logs are in `docs/graphics/reviews/zombie_simultaneous_death_v001/`. Capture readback timings are not performance measurements; the historical living-only FPS samples above do not establish performance with 50 active deaths. No solver, impulses, animations or other gameplay were optimized or changed for this correction.
