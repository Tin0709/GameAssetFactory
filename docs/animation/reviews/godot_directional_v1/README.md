# Directional movement and falling refinement — Pending review

Open `game_mobile_3d/scenes/dev/ExpressiveLocomotionTest.tscn` in Godot and press **F6**. F5 still opens production WorldMap. WASD/arrows move, Shift runs, Space jumps, R resets, F9 plays the demonstration,1/2/3 select front/three-quarter/side. **V** compares refined/original turns; **F** compares raised falling waves/original fall poses; **B** retains the heavier/original landing comparison. **L** drops from6m. E toggles the existing rifle layer.

Latest explicit pace request: **Walk/Run2.25x original**, which is1.5x faster than the previous1.5x setting. Walk2.025m/s; Run5.1975m/s. Travel and gait cadence change together; **Idle remains1x**. T cycles1/1.5/2.25x. Physics height, launch/contact events and landing timing remain unchanged.

The user approved Jump V2 and its current heavier landing direction as the **test baseline**. Production integration needs separate approval. These directional, falling and faster-pace refinements remain **Pending**.

[Original-speed refined gameplay](gameplay_1x.mp4) · [Matched original/refined comparison](comparison_1x.mp4) · [Original algorithm at the same2.25x pace](original_1x.mp4) · [Pose samples](gameplay_poses.jpg). Actual Godot Mobile/D3D12 pixels:709frames at30FPS,23.633seconds, no temporal retiming. The final6seconds show front/three-quarter/side falls. The comparison changes only the new contact/turn and falling-gesture options; both sides use the requested2.25x pace and same physics.

## Targeted runtime changes

The previous support solver rotated the character-relative leg while the body turned. Translation anchors resisted the resulting movement until the safety radius released them. The refined single-rigid-leg solve instead preserves the receiving toe heading and aims toward the planted world anchor. Swing reach follows actual travel without resetting the shared gait phase. The solved rotational offset unwinds during swing; at faster reversals, receiving continues from the actual outgoing leg orientation instead of snapping back to an unrelated authored contact. Contacts still release when the14cm correction bound is exhausted. No invented knee/ankle, scale deformation, input delay or long crossfade.

Turn response adds at most6deg total distributed hip/chest lean,2deg pelvic counter-yaw and4mm hip loading. The head counters slightly. Landing gradually admits this directional treatment rather than switching solvers abruptly. Horizontal physics and gait clocks are untouched; original/refined matched tests follow exactly the same capsule path and final gait phase.

During **descending AIR only**, falling arms reuse the existing raised Jump V2 arm pose with10deg extra shoulder lift, staggered12deg yaw /3deg pitch waves at2Hz. The full arms remain straight. Two solid legs receive opposing8deg forward/backward flutter at1.7Hz. The gesture ramps over0.20s and fades as predicted contact approaches0.19–0.05s. No extra root elevation, airborne bounce, fake joints or changes to landing targets. Very short flights can show only part of the gesture. Upper weapon layers still own their normal channels and can override these arm poses.

## Validation and remaining limits

At the final2.25x pace, **243 directional checks,183 fall-gesture checks and49 heavier/original landing comparisons pass at both30/60 renderFPS**, with60Hz physics. Turns cover Walk/Run45/90/180deg changes from both lead phases, stops and walking/running airborne turns. Tests check immediate velocity response, unchanged capsule path and gait progression, support coverage, sole clearance and angular continuity through swing/receiving/landing. Receiving and release are tested beyond consecutive planted samples; earlier large rotation resets are fixed.

Matched contact-center measurements across12flat-ground turn cases, each observed for36physics ticks:

| RenderFPS | Original cumulative planted travel | Refined cumulative planted travel | Largest refined sample |
| --- | --- | --- | --- |
|30 |0.8046m |0.0000083m |below0.001mm |
|60 |1.8228m |0.7796m |86mm |

The60FPS total is reduced about57%. The near-zero30FPS center result reflects these particular render/phase samples; **it is not proof of zero foot sliding**. Rigid boot corners still rock, rotation can move sole corners, and hard60FPS reversals release anchors by up to8.6cm per sample. Different rendering samples catch different release events; do not infer improved physical accuracy at30FPS. Faster Run has roughly9rendered poses per stride at30FPS; its largest measured turn leg step is59.46deg, versus30.51deg at60FPS. Angular guards use elapsed time and requested pace, retaining the earlier900deg/s-per-pace bound rather than pretending cadence did not change. Silhouette/foot corner quality still needs user review.

The fall test measures actual skinned head geometry: during sustained full-strength waving, both hand centers stay at least roughly3cm above the head. Entry/exit fades and weapon overlays are excluded from that height claim. Straight-arm error stays below0.001rad; arm and leg origins/scales remain unchanged.

The original **77jump stress checks pass at the preserved1.5x pace**. At the requested2.25x pace, the unchanged strict fast stress suite reports **75/77 at30FPS and76/77 at60FPS**. Two limits are retained openly: soles can read9mm below the last shared platform support plane during edge exit (the recorded sole center is beyond the platform edge, so this is not a proven9mm terrain intersection), and a weapon-arm recovery step reaches60.69deg at30FPS, just beyond the60deg guard. Existing fast repeat/short-fall arm passages are also brisk. These guards were not weakened to declare success. Terrain-aware independent contacts, full combat transitions and device30FPS performance remain unverified. Flat directional tests do not certify general terrain or production readiness.

Evidence: `turns30/60.json`, `fall_gesture30/60.json`, `landing30/60.json`, `jump_baseline30/60.json`, `jump_fast30/60.json`. The original41-check locomotion regression passes but exercises the original non-jump actor; it is supplemental, not coverage of the refined player.

## Preservation

No new Blender Action, export, rig/model/material edit or Showcase registration was needed. The entire existing Blender animation library, manifest and Showcase stay byte-identical. Production player/controllers/weapons, project settings and WorldMap remain unchanged. Existing jump actor/visual files and native libraries remain unchanged. Only isolated test hooks/configuration and new directional/fall test files change.

Exact pre-refinement copies and hashes are under `.validation/expressive_directional_v1/before/`. Additional checkpoints preserve the no-fall-wave, arms-only and1.5x stages under `before_falling_arm_request/`, `before_falling_leg_request/` and `before_pace2_25/`. Prior delivered reviews are unchanged. See `preservation_validation.json`.
