# Faster jump, smoother fast Run and repeated turns — Pending

Open `game_mobile_3d/scenes/dev/ExpressiveLocomotionTest.tscn` and press **F6**. This remains the isolated gameplay lab; production F5/WorldMap, Blender Actions and the central Showcase are unchanged.

WASD/arrows move, Shift runs, Space jumps. Default Walk/Run is **2.25×**, Idle **1×**. T compares1/1.5/2.25×. C toggles gameplay/detail framing;1/2/3 select close front/three-quarter/side views. The gameplay camera retains WorldMap's angle/offset but is now orthographic **11.25**,10% closer than the previous12.5 view, ground-anchored during flight.

## Review clips

Actual Godot Mobile/D3D12 recordings at30FPS, played at original speed; no video retiming. The2.25× locomotion setting is the runtime candidate speed, not accelerated footage.

- [Current gameplay: stationary, walking and running jumps](gameplay_1x.mp4)
- [Previous2m flight versus sharper2m flight](jump_comparison_1x.mp4)
- [Repeated rapid turns before/after](rapid_comparison_1x.mp4)
- [Fast Run foot-path/release comparison](run_comparison_1x.mp4)
- [Leg-heading/turn comparison](turn_comparison_1x.mp4)

The jump comparison uses matching cameras, inputs and the new running-flight boost on both sides. The rapid-turn comparison changes only visual facing smoothing. The Run comparison keeps the same2.25× travel speed and approved arm motion; its earlier side disables the rounded foot-path and translation-release adapters. The turn comparison preserves the captured pre-guard test and contrasts the combined refined result.

## What changed

**Jump:**2m physical height with flight factor2.15, versus retained1.9 and1.7 candidates. Measured flight is0.433s at both30/60renderFPS, reaching1.9999–2.0007m. Launch gravity/velocity scale together; collision determines touchdown. The soft0.20s preparation and heavy0.85s recovery retain their existing timing. Arms still reach the lifted airborne section. **Running prepared jumps gain15% horizontal speed while airborne**: at2.25×, about5.20→5.98m/s, returning through normal acceleration to5.20m/s after contact. Walking jumps and unprepared falls keep their existing horizontal speed; air steering remains live. Midair J comparisons affect the next launch only.

J cycles2m factors2.15/1.9/1.7, then1.35m factor1.4,1.2m factor1.18, and original1.2m factor1.0. Earlier timings remain available.

**Turns:** cached planted toe headings could wind behind the rotating pelvis. The rigid-leg axial pivot guard limits that twist to35° relative to the authored reference without changing the support aim. Measured horizontal heading error stays below51.7° in repeated reversal stress; axial and horizontal projection are different measures. P compares the guard. Rapid input changes previously reversed full body-yaw speed in one physics tick. The visible rig now accelerates/brakes its facing velocity over approximately90ms, using the shortest heading difference. Capsule input, acceleration and gait remain immediate. U compares smoothing. Peak measured yaw acceleration falls from roughly704–1215 to75–112.5rad/s² across the matched cases.

**Fast Run:** planted translation used to disappear at liftoff, causing a visible foot-path discontinuity. A short bounded cubic release carries the outgoing foot motion into swing. Above1.5×, push-off ends slightly earlier: full2.25× Run support38%LEFT/39%RIGHT,23%total flight, receiving phase0LEFT/.5RIGHT unchanged. O compares release. N compares a bounded, partial rounded sagittal foot-path blend: backward support travel, rising forward recovery, then descent. Whole cuboids remain rigid; no invented knee/ankle, wider tracks or new Action. The posing offset is at most65mm. It is a rounded running path rather than a literal wheel rotation.

Carried release and floor corrections share the existing140mm joint correction radius relative to the current posed/inertial base;65mm foot-path posing is separately bounded. Release survives Run→Walk and transfers through T/N/O comparisons. Early moving landing carries its outgoing support rotation into swing instead of dropping the offset abruptly. A test-local support-height safety lift, at most35mm, prevents initial impact poses from exceeding that correction budget; heavy landing compression/rebound remain.

## Validation and limits

**2236 checks pass across24 suites at30/60renderFPS with60Hz physics.** Evidence: [summary](checks_summary.json). Coverage includes2m flight/height, all J variants, repeated/early/long falls, both locomotion paces,45/90/180° turns, spam turns, landing handoffs, Run release/interruption, falling gestures and weapon equip/release/recovery. The strict60° upper-body and900°/s/pace leg continuity guards remain unchanged. The ballistic test now compares against the actual height/gravity/flight factor instead of an obsolete minimum0.15s duration. The ledge-loss fixture rebases contact caches when positioning at the outgoing edge, isolating support loss during recovery.

The ground-contact solver is still an approximation for rigid single-block legs: toe pivot, sole-corner rocking and anchor release remain possible during extreme reversals. In the matched2.25× turn suite, peak same-contact sole displacement is about12.5mm at60FPS; this is not a full-sole lock or terrain guarantee. Rounded recovery is intentionally restrained. General terrain, full combat coverage and actual phone performance remain unverified. Artistic/gameplay review is still required; do not promote to production or begin Combat Strafe.

Before-state scripts/reviews and intermediate checkpoints are preserved under `.validation/expressive_turn_spin_v1/`. [Preservation audit](preservation.json) protects6903 existing files, including every Blender animation/Showcase file and all production resources. No new Blender Action was created; central registration is therefore unchanged. Latest review remains Pending.
