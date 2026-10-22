# 100-zombie continuous-fire optimization — existing gameplay lab

The user reported a large frame-rate drop while shooting100zombies, recovering after release. Same saved100×100field,14,831clumps, player controls/camera/speed,6Hzfire and native death resources. No new scene or project. Native profiling separated idle, aim without firing, continuous shots and release.

## Findings and final changes

The shot manager and target scan were small compared with crowd movement and source-pose evaluation. Dense blocked chasers repeatedly ran native move-and-slide every tick. At larger counts a physics step exceeded16.67ms and the existing catch-up loop ran multiple costly steps per rendered frame. Separately, the zombie evaluator sampled Idle+Walk even when one had zero weight, and all three clips when Attack weight was1.

Only three existing dev scripts change behavior:

- `zombie_combat/source_visual.gd`: skip zero-weight clips. Full Idle/Walk now30source channel calls instead of60; full Attack30instead of90. Blends, clocks, hit layer, floor offsets and output PRS are preserved. Actual source-pose comparison worst error1.19e-7.
- `zombie_combat/physics_zombie.gd`: a small living-AI hook retains the original controller for the legacy encounter. Source poses, damage layer and native handoff samples still run every physics tick.
- `performance_lab_v001/physics_zombie.gd`: only fully blocked grounded chasers retry native movement at30Hz. Per-actor phases distribute retries (actual100allocation split49/51). AI timer delta accumulates; a bullet wakes the actor immediately. Free movement, nearby attacking actors, knockback and native death are not throttled. No collision masks/shapes, max-slides setting, solver/impulse/masses/joints, corpse lifetime or admission cap changes. Existing floor support remains necessary, so this scheduler is restricted to this dev performance wrapper.

All temporary timing/ray counters were removed. `test_zombie_hit_feedback.gd` explicitly selects its original four-actor/1.2s-death fixture; the saved performance scene retains2.5s/native all-corpse behavior.

## Actual native measurements

Apple M2Pro, Godot4.7.2 Mobile/Metal,3004×1805SubViewport, full grass, physics60Hz, render cap120/vsync disabled. Ordinary render loop; no fixed-FPS override, screenshot/readback or force_draw inside sample windows. Original three scripts were restored for the baseline run, then final authored files restored. Same scripted flow, normal HP and actual lethal hits. Counts naturally decrease during shooting; this is not an identical deterministic physics replay.

| Phase | Before averageFPS | Final averageFPS | Before frame p95 | Final frame p95 |
|---|---:|---:|---:|---:|
| Idle,100living |107.9|120.4|17.33ms|15.73ms|
| Standing heldE,6seconds |98.7|120.0|17.69ms|15.49ms|
| Run+heldE,4seconds |54.9|69.3|44.17ms|20.07ms|

Standing firing starts with100living; both runs produce35hits and end93living/3ragdolls. Moving starts at93living; before ends91with13hits, final90with18hits. Existing aim alignment gates remain, so shot count during turns is not always6per real second. Configured cadence remains1/6s, with no catch-up burst. Both have zero projectile-pool misses. Renderer CPU/GPU monitors are distinct; GPU timing is unavailable on this Metal path. Startup, shader warming and spawn spikes are outside these windows. Short capped desktop results do not establish mobile performance or sustained thermal limits.

A separate capped60stress run holds all actors alive with high HP, exercising continuous hit feedback:100stationary/moving retain~60FPS with frame p95~17.3ms.150stationary improves from about7FPS to60, but moving150and200still exceed the budget and can enter catch-up. The verified playable target for this pass is100, not an arbitrary crowd size. No population is hidden/cut to make the measurements pass. Raw capacity results are retained, including these limits.

## Correctness

- `test_horde_efficiency`: genuine red→green; inactive source samples removed, original PRS/blends equivalent.
- `test_horde_crowd`: genuine red→green; actual native wall contact,15AI retries in30physics ticks, all30source poses/handoff samples retained; free movement30/30; immediate hit wake, unblocked recovery, single death and full native cleanup.
- Current real-scene465checks each at30/60 pass, including additive100actors, spawning through death, all60native ragdolls/420parts and2.5s cleanup.
- Existing Fire60, hit feedback30/60 and23combat checks pass. Source poses, grip/recoil recovery, damage direction, transient state, slight slide/pass-through and full cleanup remain.
- Read-only focused review found no material correctness blocker. Its phase-distribution point was measured49/51.

All approved Blender Actions, source motion libraries, rifle/player/grass assets, project defaults and productionWorldMap are preserved. See `preservation.json` for hashes and comparison scope. User launch is the same saved scene with100normal-HPzombies, normal audio and existing controls; scene defaults remain20when opened directly.
