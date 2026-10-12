# Whole-body turning bank, fast Run and snappy 2m jump — Pending

Open game_mobile_3d/scenes/dev/ExpressiveLocomotionTest.tscn and press **F6**. F5/WorldMap and production resources remain unchanged. WASD/arrows move, Shift runs, Space jumps.

## Latest correction: visibly bank the entire character

The earlier lean mainly articulated hips and chest. The visible rig now banks as one unit into left/right turns, up to12 degrees at strong Run turns. The low0.45m pivot limits rigid-leg reach demands while hips, shoulders and head clearly tilt together. The capsule stays upright and controls remain immediate. World-foot contact solving remains active; restrained20% head counter-roll preserves readability. Bank eases back to upright on straight travel and fades across takeoff/landing without a state-boundary reset.

[Whole-body bank versus previous hips/chest lean](bank_comparison_1x.mp4) changes only this banking treatment. Both sides use matching inputs, timing, camera, speeds, facing smoothing and foot adapters. Previous code is safely preserved in .validation/expressive_turn_spin_v1/before_whole_body_bank.gd; --expressive-turn-bank-original reproduces its pose-only treatment.

## Controls and speed comparisons

Default base pace is2.25, plus the latest requested Walk+50% and Run+15% candidate multipliers. Ground speeds: Walk3.0375m/s, Run5.977m/s. Prepared running jumps gain another15% horizontally while airborne, reaching6.874m/s; landing returns through ordinary acceleration. Walking jumps, unprepared falls and PREP ledge losses receive no running-flight bonus.

- **T:**1x/accepted1.5x/2.25x base pace. Accepted1.5x retains Walk1.35m/s and Run3.465m/s.
- **Y:** latest faster candidate versus preceding2.25x travel speeds (Walk2.025m/s, Run5.1975m/s).
- **J:**2m factors2.15/1.9/1.7, then1.35m/1.4,1.2m/1.18 and original1.2m/1.0. Changes latch at the next intentional launch.
- **C:** gameplay/detail camera;1/2/3 choose detail front/three-quarter/side.
- **U/P:** visual facing smoothing / axial leg-pivot guard comparisons.
- **N/O:** rounded Run foot-path / support-to-swing translation-release comparisons.
- Existing V/F/G/K/B/E/L controls retain directional/fall/stride/polish/landing/weapon/drop comparisons.

Idle stays at normal speed. Gameplay camera uses WorldMap's angle and offset with orthographic11.25,10% closer than the preceding12.5 framing, ground-anchored during flight.

## Original-speed Godot review

Actual Godot Mobile/D3D12 capture at30FPS, no footage retiming:

- [Latest gameplay and physics-driven jumps](gameplay_1x.mp4)
- [Whole-body bank comparison](bank_comparison_1x.mp4)
- [Faster Walk/Run comparison](speed_comparison_1x.mp4)
- [Rapid-turn facing comparison](rapid_comparison_1x.mp4)
- [Rounded Run foot recovery/release comparison](run_comparison_1x.mp4)
- [Turn axial guard and facing comparison](turn_comparison_1x.mp4)
- [Previous1.9 versus current2.15 flight factor, both2m](jump_comparison_1x.mp4)

The speed comparison changes candidate travel/reach/cadence together. Rapid-turn comparison changes facing smoothing only. Run comparison keeps current travel/arm motion but disables the rounded recovery and translation-release adapters on the previous side. Turn comparison disables axial guard and rapid smoothing on its previous side. Jump comparison uses the same running-flight bonus and camera on both sides.

## Preserved mechanics and targeted fixes

Jump height and contact are physics-driven:2m apex, measured1.9999–2.0007m, about0.433s flight. Gravity and launch velocity scale together; unprepared falls keep normal gravity. Soft0.20s preparation and heavy0.85s recovery retain their timing and expressive arm poses.

Faster Run shares additional speed between reach and cadence through square-root scaling, preserving close tracks and rigid legs. The rounded recovery moves backward during support and forward/up/down during swing with contact tangents; its partial pose offset is bounded65mm. Full fast Run support is36%LEFT/37%RIGHT with27% total flight; receiving phase0LEFT/.5RIGHT remains shared with Walk. Accepted1.5x keeps42%/43% support.

A short cubic release carries outgoing foot position/velocity through liftoff. Carried release plus floor correction shares the existing140mm joint safety radius relative to the posed/inertial base. Earlier landing support rotation carries into swing; a bounded35mm support-height safety lift prevents deep poses exceeding the correction budget. No invented knees/ankles, scale deformation, root export arc or new Blender Action.

Cached leg axial twist is limited35deg relative to the authored reference. Visual facing accelerates/brakes over roughly90ms rather than reversing full yaw speed in one tick. Capsule input, gait progression and movement acceleration are unchanged by turning polish.

Weapon entry captures the displayed pose relative to the full native carry target once, using shortest-arc residual decay over0.30s. A1500deg/s displayed angular budget prevents combined native motion and catch-up producing a30FPS pop; a short tail catches the live target instead of snapping at blend completion. Production weapon scripts remain unchanged.

## Validation and honest limits

2282 checks across24 suites pass at30 and60 renderFPS with60Hz physics. [Evidence](checks_summary.json) covers starts/stops, both paces,45/90/180deg turns, rapid reversals, shared gait, Run release and interruptions, prepared/unprepared jumps, repeated/early/long falls, landing while moving, weapons and falling gestures. Whole-Visual roll is now measured in the rapid-turn test, including both signs and upright settling.

The60deg upper-body and900deg/s/pace leg continuity guards remain unchanged. Release acceleration uses a revised speed-normalized criterion: raw acceleration divided by run-speed-scale^1.5 must remain below300m/s^2. Both raw and normalized values are retained; current60FPS raw341m/s^2 exceeds the former absolute300 limit. It must not be represented as passing the old absolute guard. Ballistic duration is compared to height/gravity with two physics ticks tolerance; gait progress accumulates phase increments. Ledge fixture relocation rebases contact caches.

Peak same-contact sole releases in the matched hard-turn cases remain about137mm at30FPS /44mm at60FPS for the fast candidate, and117/89mm at accepted1.5x. These are visible safety releases, not perfectly planted feet. Across matched turns the refined solver reduces accumulated sliding by at least30% against its disabled comparison, but rigid cuboid corners and extreme reversals remain limitations. Terrain, full combat coverage and actual phone30FPS performance remain unverified.

All checkpoints and original clips remain in .validation/expressive_turn_spin_v1. [Preservation audit](preservation.json) checks6903 original files, including the approved Blender animation library/Showcase and production resources. Concurrent weapon-showcase work is outside this task and preserved. No new Blender Action was created, so central animation registration is unchanged.

Pending user review only. Do not promote to production or begin Combat Strafe.
