# Close melee, heavier zombie deaths and quick E combat turn

2026-10-20. Three explicit user refinements, implemented in the **same** `res://scenes/dev/ActionsStuffWalkRunTest.tscn`. No new project, scene or animation Action. Gameplay awaits user feedback; approved artistic statuses are unchanged.

## Close attacks

The dev encounter had stop1.6m/attack1.7m. The inherited AI enters Attack and stops advancing at attack range, so it held about1.679m away indefinitely. Sampling the actual approved source Attack showed the striking hand reaches about0.9m; it could not cross the remaining gap. Use stop0.85m/attack0.90m, with actual approach settling near0.872m. Preserve the source0.75s Attack, its poses, existing attack interval/windup, capsules and zero-damage research setting. Dodging out of reach may still cause a legitimate miss; no hand teleporting or stretched limbs.

`test_zombie_melee_contact.gd` checks actual animated hand OBBs against visible torso/head/straight-arm boxes (5mm tolerance), not merely capsule proximity. Repeated contacts pass from front/back/left/right and all four zombies contact the player in the live group. Arm contact is a valid hit from the side. Living capsule centers stay separated; no collision size/model/rig changes.

## Preserve shooting at that distance

The approved rifle can extend through a close zombie before the target center is beyond the muzzle. Previously the alignment gate then waited for an impossible forward ray and could stop firing. Reuse the existing cached physics ray to check the actual **grip-to-muzzle** weapon segment, with inside hits enabled. A real intersection with the selected target can satisfy close aim acquisition. On each shot, a barrel obstruction resolves through the same damage/impact/audio pipeline; otherwise the normal pooled projectile launches from the muzzle. No target damage without a real hit, backwards projectiles, homing, extra hit per shot or separate combat system. Native capture records20 barrel contacts, four kills and zero pool misses.

## Heavy, decisive death

Reuse the unchanged Lab ragdoll graph,60kg mass distribution, seven bodies/six limited loose joints, inherited velocity, CCD, collision masks and friction. Duplicate the original Rifle resource once per zombie, only in the dev wrapper:

| Parameter | Previous combat | Updated combat |
| --- | ---: | ---: |
| Total directional impulse |360N·s |240N·s |
| Upward impulse |180N·s |48N·s |
| Corpse gravity |9.8m/s² |18m/s² |
| Linear damping |0.07 |0.20 |
| Corpse lifetime |1.20s |1.20s |

Keep angular impulse/damping and joint freedom unchanged so the fall remains loose rather than stiff. The canonical Lab Rifle preset and Lab scripts are byte-identical. This is an art/gameplay response, not a ballistics claim.

In the reproducible stationary-death test, torso rise drops0.425m→0.012m, first core contact0.867s→0.450s, and maximum torso horizontal travel5.78m→2.01m. Actual rifle-hit direction and inherited pose can change the trajectory. Scene-local solver iterations increase48→96 at the same60Hz:48/64 produced unacceptable impact penetration with the stronger gravity;96 retains the existing ground/joint bounds. Original space settings restore on exit; active corpses remain capped at4/28physical bodies, promptly released. No production/player physics setting is changed. No Android/iOS performance certification is claimed.

## Fast E turnaround

The latest user request explicitly prioritizes fast combat response over the earlier long source-led stationary step sequence. While E requests Aim+Fire and a valid auto-target needs more than45deg of standing correction, latch a rapid acquisition until aligned. Small tracking adjustments retain planted source-style observation instead of releasing both feet every tick. Rapid body facing uses31.416rad/s (180deg in0.10s), and the common rifle/head/shoulder aim frame acquires at40/s. Keep the exact approved Aim pose and0.24s raise, so no firing with hands lowered. Measured first shot for a target180deg behind is about0.27s. Movement stays responsive and the gait cursor never restarts.

Release old foot anchors only during the brief stationary combat pivot and replant with the existing solver. Q/C observation and RMB aim-only keep the source turn controller/footwork; camera orbit still does not request player turning. This accelerated combat pivot is an explicitly requested Godot adapter, not an invented source animation.

## Validation and preservation

- Contact regression: reproduced zero-contact air swings before correction; visible-body contacts pass afterward from four directions and in the live group at30/60 display scheduling,60Hz physics.
- Heavy-death regression: previous launch failed torso-rise/contact-time/travel limits; updated native physics passes. Actual swept rifle kill still starts one ragdoll, preserves handoff pose/direction, reaches ground, rejects repeated death and frees all bodies at1.20s. Four simultaneous deaths remain bounded to28bodies and reset frees every graph.
- Quick-turn regression: previously no body acquisition or shot within1s for a target directly behind; updated180deg acquisition0.10s and first shot~0.27s, with raised-Aim gate and unchanged gait.
- Existing continuous-fire, nearest-target/LOS/approaching four-zombie combat, ordinary turn/contact/grip and camera checks remain in use. Approved Walk2.70/~7.55m/s, animation1×, jump, camera and source Actions are preserved.
- Native Metal Mobile30FPS capture: rear approach/actual source attack, E turn+close fire, four kills,20 point-blank contacts, maximum2 simultaneous corpses and zero pool misses. Selected frames are included; the12s AVI and generated sequence remain outside Git. Capture uses an existing wheel-zoom-equivalent size5.1 for inspection; normal scene default stays7.2/distance10m.

Run the three focused tests from `res://scenes/dev/actions_stuff_research/tests/`: `test_zombie_melee_contact.gd`, `test_zombie_weight.gd`, `test_rifle_quick_turn.gd`, with `--headless --audio-driver Dummy --fixed-fps 30` or60 and `-- --silent-review` (add user arg30 for the melee report label). The existing zombie-combat test now expects the explicitly requested240/48 impulse, while retaining its original contact/error/cleanup limits.

See numeric reports and `preservation.json`. All original Blender sources/Showcases, source animation libraries, weapon model, core Lab physics files, production gameplay and WorldMap remain exact. New code/data remain under the export-excluded research root. No manual commit/push, history rewrite, tracking migration or large generated Git artifacts.
