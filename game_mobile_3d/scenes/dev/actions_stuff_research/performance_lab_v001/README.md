# Adjustable zombie performance lab — existing scene only

Current `res://scenes/dev/ActionsStuffWalkRunTest.tscn` opts into `performance_test_enabled=true`. It now contains100×100 unit ground blocks and14,831 enabled randomized short/tall grass clumps, with the approved player/rifle, lighting controls and movement. The optional lighting review blocks/trees/flowers and their colliders are omitted. WorldMap, project defaults, approved Blender files, existing grass assets and native AI/animation/death behavior are preserved. Latest contact gain is1.5×; wind and spring timing remain unchanged.

## Controls

- Default: 20 living zombies, simultaneously instantiated.
- Bottom-left **Performance Test**: slider selects every integer 0–50, with 0/10/20/50 shortcuts. Selecting changes the pending count; **Spawn +N** adds N actors to those already present in one batch. The limit50 applies per click, not total population:20→40→60 and100accumulated are verified.
- **Spawn +0** changes no existing actors. For an empty baseline, select0, clickSpawn+0, then pressR for the explicit reset.
- **Kill All** applies lethal damage to every survivor immediately. Every spawned actor runs its existing native death at the same time, including every accumulated actor (60ragdolls/420physical parts verified this update). No corpse is culled or queued to hide the load. Every corpse currently retains a 2.5-second lifecycle.
- **R** resets player/fire/targets and restores the last applied batch count. Unapplied slider changes do not alter R.
- **V** keeps the existing whole-field overview; E/aim/fire, movement, jump, Q/C and camera controls are unchanged. There are no automatic waves or respawns.

## Implementation and preservation

The existing encounter shares its original actor construction through `_spawn_zombies`; reset still frees all old graphs. This subclass selects valid rings near the current player, using a sparse occupancy grid only per button click, .75m separation from all living actors, map bounds and2m player clearance. Unique serial names survive repeated additions. Corpse positions are ignored because their approved physics already passes through live actors. A physically full arena may add fewer than requested; there is no hidden total-count cap. All spawned actors start their existing persistent chase, with unchanged speed/melee/source clips. Spawn is event-driven, not streamed across frames. The performance actor reuses the original native-death implementation without admission limits. The latest authorized experiment doubles directional/lift impulses, extends cleanup to 2.5s and adds native floor-contact planar arrest; the original handoff, masses, gravity, joints, CCD and source clips remain unchanged. The original four-actor opt-out fixture keeps its previous death settings.

Spawn preserves active auto-aim targets/projectiles, survivors, corpses and kill statistics. KillAll/reset retain their existing target/fire cleanup. Controls use no keyboard focus and refresh telemetry at4Hz. The explicit `spawn_batch` replacement helper remains for legacy fixtures; the UI exclusively calls `add_batch`. `Frame` is 1000/FPS, not GPU time. `Process`/`Physics` are Godot's CPU monitor timings. The existing lighting panel still shows render counters/quality/time. GPU timing remains N/A on this tested Metal path.

The opt-in defaults false in the shared lab script. Setting it false restores the original four-zombie fixture plus lighting review props. Legacy four-actor combat, auto-aim and hit-feedback capture fixtures explicitly opt out. No production scene is affected.

## Current combat-feel experiment

The saved lab now restores the complete wind/contact/shadow version via `grass_vegetation_enabled=true` on its100m map; the earlier temporary grass pause is superseded. Performance mode levels rifle flight from the actual muzzle, increases projectile speed20→30m/s and range15→45m, and excludes only invisible arena walls from bullet rays. The shared production weapon profile is unchanged. `physics_zombie.gd` duplicates the existing combat preset and changes240→480N·s directional/48→96N·s lift once; this doubles impulse-derived speed with the same masses. `grounded_part.gd` extends the original guard and arrests XZ velocity after a Hips/Chest/Head contact with the flatY0 ground, without changing native transforms, falling or angular motion. Corpse friction is1.0; lifetime2.5s. No hidden ragdoll cap is restored. See `docs/graphics/reviews/combat_feel_v001/README.md`.

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

## Latest expanded-map/addition verification

465actual-scene checks each at30/60: all10,000 cells planted, expanded terrain/collisions/camera overview/contact dimensions, far-edge contact/reset, additive20→40→60 and100accumulated, existing actor/native graph/aim preservation, Spawn+0,60simultaneous deaths/420parts, spawn during death,2.5s cleanup, statistics, explicitR and original four-actor opt-out.29grass contracts,23combat checks and Fire30 also pass. Native196² render-history check has zero held subframes. Actual Mobile/Metal full-map/gameplay/60-death pixels and contact motion reviewed. Desktop capped60 sampling uses the ordinary render loop without fixedFPS/readback/forced draw in its windows; no Android/iOS claim. Evidence: `docs/graphics/reviews/expanded_grass_additive_v001/README.md`. Earlier verification sections retain historical behavior and counts.
